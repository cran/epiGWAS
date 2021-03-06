#' Implements BOOST SNP-SNP interaction test
#'
#' For a pair of SNPs (\eqn{X_1}{X1}, \eqn{X_2}{X2}) and a binary phenotype
#' \eqn{Y}{Y}, the \code{\link{BOOST}} function computes the ratio of maximum
#' log-likelihoods for two models: the full model and the main effects model.
#' Mathematically speaking, the full model is a logistic regression model with
#' both main effects and interaction terms
#' \eqn{\left(X_1, X_2, X_1\times X_2\right)}{(X1, X2, X1, X1 x X2)}.
#' The main effects model is a logistic regression model with only
#' \eqn{\left(X_1, X_2\right)}{(X1, X2)} as covariates. Since we are
#' interested in the synergies with a single variant, we do not implement
#' the initial sure screening stage in BOOST which filters out non-significant
#' pairs.
#'
#' @seealso The webpage \url{http://bioinformatics.ust.hk/BOOST.html} provides
#' additional details about the BOOST software
#'
#' @param A target variant. The SNP A is encoded as 0, 1, 2.
#' @param X genotype matrix (excluding A). The only accepted SNP values are
#' also 0, 1 and 2.
#' @param Y observed phenotype. Binary or two-level factor.
#' @param ncores number of threads (default 1)
#'
#' @return The interaction statistic between each column in \code{X} and \code{A}
#'
#' @examples
#' X <- matrix((runif(500, min = 0, max = 1) < 0.5) +
#'     (runif(500, min = 0, max = 1) < 0.5), nrow = 50)
#' A <- (runif(50, min = 0, max = 1) < 0.5) + (runif(50, min = 0, max = 1) < 0.5)
#' Y <- runif(50, min = 0, max = 1) < 1/(1+exp(-.5 * A * X[, 3] + .25 * A * X[, 7]))
#' BOOST(A, X, Y)
#'
#' @export
BOOST <- function(A, X, Y, ncores = 1) {
  stopifnot(ncores <= parallel::detectCores())
  stopifnot(dim(X)[1] == length(A))
  stopifnot(dim(X)[1] == length(Y))
  stopifnot(setequal(levels(as.factor(A)), c(0, 1, 2)))
  stopifnot(setequal(levels(as.factor(X)), c(0, 1, 2)))
  stopifnot(is.factor(Y) | is.logical(Y))

  # Internal function for computing the likelihood ratio statistic
  ratio <- function(z) {
    data_AX <- data.frame(x1 = factor(A), x2 = factor(z), y = Y)
    fit01 <- stats::glm(y ~ x1 + x2, family = "binomial", data = data_AX)
    fit2 <- stats::glm(y ~ x1 + x2 + x1 * x2, family = "binomial", data = data_AX)

    return(fit01$dev - fit2$dev)
  }

  if (ncores == 1) {
    loglikelihood <- apply(X, 2, ratio)
  } else {
    if (requireNamespace("doParallel", quietly = TRUE)) {
      cl <- parallel::makeCluster(ncores)
      doParallel::registerDoParallel(cl)

      loglikelihood <- parallel::parApply(cl, X, 2, ratio)

      parallel::stopCluster(cl)
    } else {
      warning("Multithreading requires the installation of the doParallel package")
      loglikelihood <- apply(X, 2, ratio)
    }
  }

  return(loglikelihood)
}
