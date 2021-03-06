% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/estimate.R
\name{cellTypeEstimate}
\alias{cellTypeEstimate}
\title{Calculate cell type profile estimations}
\usage{
cellTypeEstimate(exprData, genes, geneColName = "Gene.Symbol",
  outlierSampleRemove = FALSE, synonymTaxID = NULL,
  geneTransform = function(x) {     mouse2human(x)$humanGene }, groups,
  tableOut = NULL, indivGenePlot = NULL, seekConsensus = F,
  removeNegatives = TRUE, plotType = c("groupBased", "cummulative"),
  PC = 1)
}
\arguments{
\item{exprData}{data.frame. Expression data. First collumns of the expression data should include gene names in the 
same format as the ones specified in the marker gene lists. Any other non-expression related fields must not be of
type 'double'}

\item{genes}{a named list containing marker gene lists of each cell type}

\item{geneColName}{character. name of the column containing the gene names in the expression file}

\item{outlierSampleRemove}{logical. should the outlier samples be removed from the final output}

\item{synonymTaxID}{Taxonomy identifier of the source of cell type markers. If provided, synonyms of the genes will 
be added as markers, not recommended since unrelated genes can share names}

\item{geneTransform}{a function that will be applied to the gene list. the default behavior is to change mouse genes 
to human genes. set to NULL to keep the genes as they are}

\item{groups}{a vector stating which groups each sample belongs to}

\item{tableOut}{character, filename. If provided outputs loadings of individual genes and variance explained by
principal components}

\item{indivGenePlot}{a character vector. If provided, plots expression of marker genes in individual groups per
marker gene list. Is not guaranteed to look pretty.}

\item{seekConsensus}{logical. If TRUE any gene with negative loadings in any of the groups individually will be
removed. Use if there is a high likelihood of gene regulation between the groups.}

\item{removeNegatives}{logical. should the genes with negative loadings be removed from the estimation. Setting 
seekConsensus to TRUE makes this irrelevant. As all negatives will be removed at that step}

\item{plotType}{if indivGenePlot is provided, type of plot to be saved. groupBased separates expression between groups
cummulative plots a single value}

\item{PC}{which principal component to use. For debugging purposes. Recommended value is always 1}
}
\description{
Primary function for cell type profile estimations.
}
