#!/usr/bin/env Rscript

args = commandArgs( trailingOnly=TRUE )
if (length(args)==0) {
  stop("At least one argument must be supplied (input file).", call.=FALSE)
}

my_data <- read.csv( args[1], header=FALSE )
x <- my_data[, 1]
y <- my_data[, 2]
res <- cor.test( x, y, method = "pearson" )
res
r2 = res$estimate * res$estimate
names(r2)[1] <- "r^2"
r2

cor.test( x, y, method = "spearman" )
cor.test( x, y, method = "kendall" )
