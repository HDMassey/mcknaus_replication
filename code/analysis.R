# analysis.R
# Reads temp/clean_data.RData, runs DML, and creates the Table 4 replication artifacts.

suppressPackageStartupMessages({
  library(causalDML)
  library(grf)
  library(lmtest)
  library(sandwich)
})

root <- normalizePath(file.path(dirname(commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))][1]), ".."), mustWork = FALSE)
if (is.na(root) || root == ".") root <- getwd()
setwd(root)

clean_path <- file.path("temp", "clean_data.RData")
if (!file.exists(clean_path)) {
  stop("Missing temp/clean_data.RData. Run code/preprocess.R first.")
}

load(clean_path)

dir.create(file.path("output", "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("output", "tables"), recursive = TRUE, showWarnings = FALSE)

dml_path <- file.path("temp", "DML_forest_500.rds")

if (file.exists(dml_path)) {
  DML <- readRDS(dml_path)
} else {
  set.seed(1234)
  forest_500 <- create_method(
    "forest_grf",
    args = list(
      num.trees = 500,
      min.node.size = 10,
      seed = 1234
    )
  )
  DML <- DML_aipw(
    y = y,
    w = w,
    x = x,
    ml_w = list(forest_500),
    ml_y = list(forest_500),
    quiet = TRUE
  )
  saveRDS(DML, dml_path)
}

ate_cols <- c(
  "job search - no program",
  "vocational - no program",
  "computer - no program",
  "language - no program"
)

if (!all(ate_cols %in% colnames(DML$ATE$delta))) {
  print(colnames(DML$ATE$delta))
  stop("ATE column names do not match expected treatment comparisons.")
}

delta <- DML$ATE$delta[, ate_cols, drop = FALSE]
colnames(delta) <- c("Job search\n(1)", "Vocational\n(2)", "Computer\n(3)", "Language\n(4)")

female <- as.numeric(x[, "female"])
foreigner <- as.numeric(x[, "foreigner_b"] + x[, "foreigner_c"] > 0)
emp_raw <- x[, "employability"]
emp_levels <- sort(unique(emp_raw))
emp_medium <- as.numeric(emp_raw == emp_levels[2])
emp_high <- as.numeric(emp_raw == emp_levels[3])

stars <- function(p) {
  ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", "")))
}
fmt_coef <- function(b, p) paste0(sprintf("%.2f", b), stars(p))
fmt_se <- function(se) paste0("(", sprintf("%.2f", se), ")")

fit_gate <- function(yvar, dat, rhs, coef_names) {
  dat$yvar <- yvar
  mod <- lm(as.formula(paste("yvar ~", rhs)), data = dat)
  ct <- coeftest(mod, vcov = vcovHC(mod, type = "HC1"))
  out <- list()
  for (v in coef_names) {
    out[[paste0(v, "_coef")]] <- fmt_coef(ct[v, "Estimate"], ct[v, "Pr(>|t|)"])
    out[[paste0(v, "_se")]] <- fmt_se(ct[v, "Std. Error"])
  }
  out
}

robust_f_test <- function(yvar) {
  dat <- data.frame(yvar = yvar, emp_medium = emp_medium, emp_high = emp_high)
  mod <- lm(yvar ~ emp_medium + emp_high, data = dat)
  V <- vcovHC(mod, type = "HC1")
  b <- coef(mod)[c("emp_medium", "emp_high")]
  V_sub <- V[c("emp_medium", "emp_high"), c("emp_medium", "emp_high")]
  q <- length(b)
  F_stat <- as.numeric(t(b) %*% solve(V_sub) %*% b / q)
  p_val <- pf(F_stat, df1 = q, df2 = mod$df.residual, lower.tail = FALSE)
  paste0(sprintf("%.2f", F_stat), stars(p_val))
}

row_names <- c(
  "Panel A: Female", "Constant", "", "Female", "",
  "Panel B: Foreigner", "Constant", "", "Foreigner", "",
  "Panel C: Employability", "Constant", "", "Medium employability", "",
  "High employability", "", "F-statistic"
)

table4 <- data.frame(
  " " = row_names,
  "Job search\n(1)" = "",
  "Vocational\n(2)" = "",
  "Computer\n(3)" = "",
  "Language\n(4)" = "",
  check.names = FALSE
)

for (j in seq_len(ncol(delta))) {
  yj <- delta[, j]
  cj <- colnames(delta)[j]

  a <- fit_gate(yj, data.frame(female = female), "female", c("(Intercept)", "female"))
  table4[2, cj] <- a[["(Intercept)_coef"]]
  table4[3, cj] <- a[["(Intercept)_se"]]
  table4[4, cj] <- a[["female_coef"]]
  table4[5, cj] <- a[["female_se"]]

  b <- fit_gate(yj, data.frame(foreigner = foreigner), "foreigner", c("(Intercept)", "foreigner"))
  table4[7, cj] <- b[["(Intercept)_coef"]]
  table4[8, cj] <- b[["(Intercept)_se"]]
  table4[9, cj] <- b[["foreigner_coef"]]
  table4[10, cj] <- b[["foreigner_se"]]

  c <- fit_gate(yj, data.frame(emp_medium = emp_medium, emp_high = emp_high), "emp_medium + emp_high", c("(Intercept)", "emp_medium", "emp_high"))
  table4[12, cj] <- c[["(Intercept)_coef"]]
  table4[13, cj] <- c[["(Intercept)_se"]]
  table4[14, cj] <- c[["emp_medium_coef"]]
  table4[15, cj] <- c[["emp_medium_se"]]
  table4[16, cj] <- c[["emp_high_coef"]]
  table4[17, cj] <- c[["emp_high_se"]]
  table4[18, cj] <- robust_f_test(yj)
}

write.csv(table4, file.path("output", "tables", "table4_replication.csv"), row.names = FALSE)

# Draw the table as a PNG to avoid LaTeX package problems.
table_png <- file.path("output", "figures", "table4_replication_output.png")
png(filename = table_png, width = 1800, height = 1400, res = 200)
par(mar = c(1, 1, 3, 1))
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))
text(0.5, 0.98, "Group average treatment effects", font = 2, cex = 1.2)
x_pos <- c(0.08, 0.43, 0.60, 0.76, 0.91)
y_start <- 0.92
row_step <- 0.043
headers <- colnames(table4)
text(x_pos[1], y_start, headers[1], font = 2, adj = 0, cex = 0.75)
for (k in 2:5) text(x_pos[k], y_start, headers[k], font = 2, cex = 0.75)
segments(0.05, y_start - 0.025, 0.95, y_start - 0.025, lwd = 1)
for (i in seq_len(nrow(table4))) {
  y_i <- y_start - 0.04 - (i - 1) * row_step
  if (i %in% c(1, 6, 11)) {
    text(x_pos[1], y_i, table4[i, 1], font = 3, adj = 0, cex = 0.75)
  } else {
    text(x_pos[1], y_i, table4[i, 1], adj = 0, cex = 0.72)
    for (k in 2:5) text(x_pos[k], y_i, table4[i, k], cex = 0.72)
  }
}
segments(0.05, 0.105, 0.95, 0.105, lwd = 1)
note_text <- paste(
  "Notes: OLS coefficients and heteroscedasticity robust standard errors in parentheses.",
  "Regressions use the DML pseudo-outcome. * p < 0.1; ** p < 0.05; *** p < 0.01."
)
text(0.05, 0.065, note_text, adj = 0, cex = 0.58)
dev.off()

# A LaTeX fragment that paper.tex can input. It includes the generated PNG.
tex_fragment <- paste0(
  "\\begin{figure}[h]\n",
  "\\centering\n",
  "\\includegraphics[width=0.95\\textwidth]{../output/figures/table4_replication_output.png}\n",
  "\\caption{Replication of Table 4: Group average treatment effects}\n",
  "\\label{fig:table4rep}\n",
  "\\end{figure}\n"
)
writeLines(tex_fragment, file.path("output", "tables", "table4_replication.tex"))

cat("Replication Result\n")
cat("==================\n")
cat("Target: Knaus Table 4, group average treatment effects.\n")
cat("Output figure:", table_png, "\n")
cat("Output LaTeX fragment: output/tables/table4_replication.tex\n")
cat("Sample size used:", length(y), "\n")
cat("Covariates used:", ncol(x), "\n")
