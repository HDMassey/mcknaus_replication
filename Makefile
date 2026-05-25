.PHONY: all clean

all: paper/paper.pdf

temp/clean_data.RData: code/preprocess.R
	Rscript code/preprocess.R

output/figures/table4_replication_output.png output/tables/table4_replication.tex: temp/clean_data.RData code/analysis.R
	Rscript code/analysis.R

paper/paper.pdf: paper/paper.tex output/figures/table4_replication_output.png output/tables/table4_replication.tex
	cd paper && pdflatex paper.tex && pdflatex paper.tex

clean:
	rm -f temp/*.RData temp/*.rds output/figures/*.png output/tables/*.tex output/tables/*.csv paper/*.aux paper/*.log paper/*.out paper/*.toc paper/paper.pdf
