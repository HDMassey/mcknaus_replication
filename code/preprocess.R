# preprocess.R
# Reads restricted raw Swiss ALMP data from input/, constructs analysis-ready objects,
# and saves them to temp/clean_data.RData.

suppressPackageStartupMessages({
  library(dplyr)
  library(grf)
})

root <- normalizePath(file.path(dirname(commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))][1]), ".."), mustWork = FALSE)
if (is.na(root) || root == ".") root <- getwd()
setwd(root)

csv_path <- file.path("input", "1203_ALMP_Data_E_v1.0.0.csv")
zip_path <- file.path("input", "swissubase_1203_1_0.zip")

if (!file.exists(csv_path)) {
  if (file.exists(zip_path)) {
    unzip(zip_path, exdir = "input")
  } else {
    stop("Raw data not found. Place 1203_ALMP_Data_E_v1.0.0.csv or swissubase_1203_1_0.zip in input/.")
  }
}

if (!file.exists(csv_path)) {
  stop("Could not find input/1203_ALMP_Data_E_v1.0.0.csv after unzipping. Check input/README.md.")
}

db <- read.csv(csv_path)

covariates <- c(
  "age", "canton_moth_tongue", "city_big", "city_medium", "city_no",
  "cw_age", "cw_cooperative", "cw_educ_above_voc", "cw_educ_tertiary",
  "cw_female", "cw_missing", "cw_own_ue", "cw_tenure", "cw_voc_degree",
  "emp_share_last_2yrs", "emp_spells_5yrs", "employability", "female",
  "foreigner_b", "foreigner_c", "gdp_pc", "married", "other_mother_tongue",
  "past_income", "prev_job_manager", "prev_job_sec_mis", "prev_job_sec1",
  "prev_job_sec2", "prev_job_sec3", "prev_job_self", "prev_job_skilled",
  "prev_job_unskilled", "qual_semiskilled", "qual_degree", "qual_unskilled",
  "qual_wo_degree", "swiss", "ue_cw_allocation1", "ue_cw_allocation2",
  "ue_cw_allocation3", "ue_cw_allocation4", "ue_cw_allocation5",
  "ue_cw_allocation6", "ue_spells_last_2yrs", "unemp_rate"
)

missing_vars <- setdiff(c(covariates, "canton_german", "treatment6", "start_q2", paste0("employed", 1:36)), names(db))
if (length(missing_vars) > 0) {
  stop(paste("Missing expected variables:", paste(missing_vars, collapse = ", ")))
}

# Keep the German-speaking sample and the five treatment categories used in Table 4.
db <- db %>%
  filter(canton_german == 1) %>%
  filter(!(treatment6 %in% c("employment", "personality")))

# Initial covariate matrix for pseudo-start prediction.
x_initial <- as.matrix(db %>% select(all_of(covariates)))

# For the no-program group, assign a pseudo-start indicator for months 4-6.
# This follows the idea in Knaus: estimate timing from treated units, then simulate timing for nonparticipants.
set.seed(1234)
rf_late <- regression_forest(
  X = x_initial[db$treatment6 != "no program", ],
  Y = db$start_q2[db$treatment6 != "no program"],
  tune.parameters = "all",
  seed = 1234
)

p_late <- predict(rf_late, newdata = x_initial[db$treatment6 == "no program", ])
p_late_vec <- as.numeric(p_late$predictions)
p_late_vec <- pmin(pmax(p_late_vec, 0), 1)

db$elap <- db$start_q2
set.seed(1234)
n_no_program <- sum(db$treatment6 == "no program")
db$elap[db$treatment6 == "no program"] <- as.numeric(runif(n_no_program) < p_late_vec)

# Keep individuals unemployed at the relevant observed or pseudo-start point.
db <- db %>% filter(!(elap == 1 & (employed1 == 1 | employed2 == 1 | employed3 == 1)))

# Final covariate matrix.
x <- as.matrix(db %>% select(all_of(covariates)))

# Treatment factor.
w <- factor(
  db$treatment6,
  levels = c("no program", "job search", "vocational", "computer", "language")
)
label_w <- c("No program", "Job search", "Vocational", "Computer", "Language")
label_x <- colnames(x)

# Outcome: months employed in a 31-month post-start window.
emp <- matrix(NA, nrow = nrow(db), ncol = 31)
emp[db$elap == 0, ] <- as.matrix(db[db$elap == 0, paste0("employed", 3:33)])
emp[db$elap == 1, ] <- as.matrix(db[db$elap == 1, paste0("employed", 6:36)])
y <- rowSums(emp)

z_blp <- data.frame(
  female = x[, "female"],
  age = x[, "age"],
  foreigner = x[, "foreigner_b"] + x[, "foreigner_c"],
  employability = factor(x[, "employability"]),
  past_incomein10000 = x[, "past_income"] / 10000
)

x_pt_low <- cbind(
  Age = x[, "age"],
  Employability = x[, "employability"],
  Female = x[, "female"],
  Foreigner = x[, "foreigner_b"] + x[, "foreigner_c"],
  `Past income` = x[, "past_income"]
)

x_pt_high <- x

if (!dir.exists("temp")) dir.create("temp")
save(db, y, w, x, z_blp, x_pt_low, x_pt_high, label_w, label_x, file = file.path("temp", "clean_data.RData"))

cat("Preprocessing complete\n")
cat("======================\n")
cat("N observations:", length(y), "\n")
cat("N covariates:", ncol(x), "\n")
cat("Mean outcome:", round(mean(y), 4), "\n")
cat("SD outcome:", round(sd(y), 4), "\n")
cat("Treatment counts:\n")
print(table(w))
