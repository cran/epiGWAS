% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/model.R
\name{sample_SNP}
\alias{sample_SNP}
\title{Samples causal SNPs with different effect types}
\usage{
sample_SNP(nX, nY, nZ12, clusters, MAF, thresh_MAF = 0.2,
  window_size = 3, overlap_marg = 0, overlap_inter = 0,
  max_iter = 10000)
}
\arguments{
\item{nX}{number of SNPs interacting with the target variant}

\item{nY}{number of SNPs with marginal effects}

\item{nZ12}{number of SNP pairs with epistatic effects}

\item{clusters}{vector of cluster memberships. Typically, the output
of \code{\link[stats]{cutree}}. For ease of identification,
the SNP IDs in \code{names(clusters)} are mandatory.}

\item{MAF}{vector of minor allele frequencies. The order of the SNPs in
\code{MAF} is identical to that in \code{clusters}.}

\item{thresh_MAF}{lower-bound on the minor allele frequencies of
causal SNPs. Rare variants are inherently difficult to recover. Assessing
the retrieval performance on common variants better reflects the true
performance of the epistasis detection algorithm.}

\item{window_size}{in number of clusters. Beside the target variant, the
causal SNPs are sampled outside of a window centered around the
target. On each side of the target variant, the width of the window
is \code{window_size}.}

\item{overlap_marg}{number of SNPs with both synergistic effects with the
target and marginal effects}

\item{overlap_inter}{number of SNPs with both synergistic effects with the
target and additional epistatic effects}

\item{max_iter}{maximum number of sampling rejections for each SNP.
If exceeded, the function generates an error}
}
\value{
list of character vectors containing to the causal SNP IDs. The
  output list entries are: target, marginal, inter1 and inter2. An
  epistatic pair is obtained from the combination of two SNPs with
  identical positions in \code{inter1} and \code{inter2}.
}
\description{
The sampled SNPs are combined in a list of character vectors with the
following fields: target, marginal, inter1 and inter2. Through the
parameters \code{overlap_marg} and \code{overlap_inter}, the synergistic
SNPs with the target can have additional marginal and epistatic effects. The
SNPs are consecutively sampled in the following order: target, marginal,
inter1 and inter2. For each SNP, we iteratively sample until the picked
SNP candidate meets the constraints defined by \code{thresh_MAF} and
\code{window_size} (see arguments for more details) or until the maximum
number of resamplings is reached. To avoid duplication of effects, we
sample at most one SNP per cluster.
}
\section{Warning}{

Make sure to supply the SNP IDs in \code{names(clusters)}. The SNPs in
the output list are referenced by their names.
}

\examples{
clusters <- rep(seq_len(10), each = 3)
names(clusters) <- paste0("SNP_", seq_along(clusters))
MAF <- runif(length(clusters), min = 0.1, max = 0.5)

sample_SNP(nX = 2, nY = 2, nZ12 = 1, clusters, MAF, thresh_MAF = 0.2,
           window_size = 2, overlap_marg = 1, overlap_inter = 0)

}
