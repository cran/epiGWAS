#' Applies the forward algorithm to a single observation
#'
#' The forward algorithm is applied in order to compute the joint
#' probability for the observation \code{x}. For hidden Markov models,
#' the forward algorithm is an attractive option because of its
#' linear complexity in the number of hidden states. However, the
#' complexity becomes quadratic in terms of the dimensionality of
#' the latent space.
#'
#' @param x one-sample genotype
#' @param p_init marginal distributions for the first hidden state
#' @param p_trans 3D dimensional array for the transition probabilities
#' @param p_emit 3D dimensional array for the emission probabilities
#'
#' @return Joint probability for the state x in a log form
#'
#' @details Our implementation of the forward algorithm
#' makes use of the LogSumExp transformation for increased
#' numerical stability.
#'
#' @references Rabiner, Lawrence R. 'A tutorial on hidden Markov models
#' and selected applications in speech recognition.' Proceedings of the
#' IEEE 77.2 (1989): 257-286.
#'
#' @examples
#' p <- 3 # Number of states
#' K <- 2 # Dimensionality of the latent space
#'
#' p_init <- rep(1 / K, K)
#' p_trans <- array(runif((p - 1) * K * K), c(p - 1, K, K))
#' # Normalizing the transition probabilities
#' for (j in seq_len(p - 1)) {
#'   p_trans[j, , ] <- p_trans[j, , ] / (matrix(rowSums(p_trans[j, , ]), ncol = 1) %*% rep(1, K))
#' }
#'
#' p_emit <- array(stats::runif(p * 3 * K), c(p, 3, K))
#' # Normalizing the emission probabilities
#' for (j in seq_len(p)) {
#'   p_emit[j, , ] <- p_emit[j, , ] / (matrix(rep(1, 3), ncol = 1) %*% colSums(p_emit[j, , ]))
#' }
#'
#' X <- (runif(p, min = 0, max = 1) < 0.5) + (runif(p, min = 0, max = 1) < 0.5)
#'
#' # Computing the joint log-probabilities
#' log_prob <- forward_sample(X, p_init, p_trans, p_emit)
#'
#' @export
forward_sample <- function(x, p_init, p_trans, p_emit) {
  stopifnot((length(dim(p_trans)) == 3) & (length(dim(p_emit)) == 3) &
    is.vector(p_init))
  stopifnot(length(x) == (dim(p_trans)[1] + 1))
  stopifnot(length(p_init) == dim(p_trans)[2])
  stopifnot(dim(p_trans)[2] == dim(p_trans)[3])
  stopifnot(dim(p_trans)[2] == dim(p_emit)[3])
  stopifnot((dim(p_trans)[1] + 1) == dim(p_emit)[1])
  stopifnot(dim(p_emit)[2] == 3)

  mat_one <- array(1, dim = rep(length(p_init), 2))
  p_obs <- log(p_init) + log(p_emit[1, x[1] + 1, ])
  for (i in seq(2, length(x))) {
    p_obs <- matrixStats::rowLogSumExps(log(t(p_trans[i - 1, , ])) +
      mat_one %*% diag(p_obs)) + log(p_emit[i, x[i] + 1, ])
  }

  return(matrixStats::logSumExp(p_obs))
}

#' Applies the forward algorithm to a genotype dataset
#'
#' Applies the \code{forward_sample} function to each row in \code{X}. If
#' the \code{ncores} > 1, the function calling is performed in a parallel
#' fashion to reduce the running time. The parallelization backend
#' is \code{doParallel}.  If the latter package is not installed,
#' the function switches back to single-core mode.
#'
#' @param X genotype matrix. Each row corresponds to a separate sample
#' @param p_init marginal distributions for the first hidden state
#' @param p_trans 3D dimensional array for the transition probabilities
#' @param p_emit 3D dimensional array for the emission probabilities
#' @param ncores number of threads (default 1)
#'
#' @return A vector of log probabilities
#'
#' @references Rabiner, Lawrence R. 'A tutorial on hidden Markov models
#' and selected applications in speech recognition.' Proceedings of the
#' IEEE 77.2 (1989): 257-286.
#'
#' @examples
#' p <- 3 # Number of states
#' K <- 2 # Dimensionality of the latent space
#'
#' p_init <- rep(1 / K, K)
#' p_trans <- array(runif((p - 1) * K * K), c(p - 1, K, K))
#' # Normalizing the transition probabilities
#' for (j in seq_len(p - 1)) {
#'   p_trans[j, , ] <- p_trans[j, , ] / (matrix(rowSums(p_trans[j, , ]), ncol = 1) %*% rep(1, K))
#' }
#'
#' p_emit <- array(stats::runif(p * 3 * K), c(p, 3, K))
#' # Normalizing the emission probabilities
#' for (j in seq_len(p)) {
#'   p_emit[j, , ] <- p_emit[j, , ] / (matrix(rep(1, 3), ncol = 1) %*% colSums(p_emit[j, , ]))
#' }
#'
#' n <- 2
#' X <- matrix((runif(n * p, min = 0, max = 1) < 0.4) +
#'             (runif(n * p, min = 0, max = 1) < 0.4), nrow = 2)
#'
#' # Computing the joint log-probabilities
#' log_prob <- forward(X, p_init, p_trans, p_emit)
#'
#' @export
forward <- function(X, p_init, p_trans, p_emit, ncores = 1) {
  stopifnot(ncores <= parallel::detectCores())
  stopifnot((length(dim(p_trans)) == 3) | (length(dim(p_emit)) == 3) |
    is.vector(p_emit))
  stopifnot(dim(X)[2] == (dim(p_trans)[1] + 1))
  stopifnot(length(p_init) == dim(p_trans)[2])
  stopifnot(dim(p_trans)[2] == dim(p_trans)[3])
  stopifnot(dim(p_trans)[2] == dim(p_emit)[3])
  stopifnot((dim(p_trans)[1] + 1) == dim(p_emit)[1])
  stopifnot(dim(p_emit)[2] == 3)

  if (ncores == 1) {
    p_obs <- apply(X, 1, function(z) return(forward_sample(
        z, p_init,
        p_trans, p_emit
      )))
  } else {
    if (requireNamespace("doParallel", quietly = TRUE)) {
      cl <- parallel::makeCluster(ncores)
      parallel::clusterExport(cl, "forward_sample")
      doParallel::registerDoParallel(cl)

      p_obs <- parallel::parApply(cl, X, 1, function(z) return(forward_sample(
          z,
          p_init, p_trans, p_emit
        )))

      parallel::stopCluster(cl)
    } else {
      warning("Multithreading requires the installation of the doParallel package")
      p_obs <- apply(X, 1, function(z) return(forward_sample(
          z, p_init,
          p_trans, p_emit
        )))
    }
  }

  return(p_obs)
}

#' Computes the propensity scores
#'
#' In this function, and for each sample, we compute both propensity scores
#' \eqn{P(A=1| X)}{P(A=1|X)} and \eqn{P(A=0| X)}{P(A=0|X)}. The
#' application of the forward algorithm on the passed \code{hmm} allows us to
#' estimate the joint probability of (A, X), for all values of the target
#' variant A = 0, 1, 2. The Bayes formula yields the corresponding conditional
#' probabilities. Depending on the binarization rule, we combine them to
#' obtain the propensity scores.
#'
#' @param X genotype matrix. Make sure to assign \code{colnames(X)} beforehand.
#' @param target_name target variant name
#' @param hmm fitted parameters of the fastPHASE hidden Markov model. The HMM
#' model is to be fitted with the \code{\link{fast_HMM}} function.
#' @param binary if \code{TRUE}, the target SNP values 0 and (1,2)
#' are respectively mapped to 0 and 1. That describes a dominant mechanism.
#' Otherwise, if \code{FALSE}, we encode a recessive mechanism where the values
#' 0 and 1 respectively map to (0,1) and 2.
#' @param ncores number of threads (default 1)
#'
#' @return Two-column propensity score matrix. The first column lists the
#' propensity score \eqn{P\left(A=0| X\right)}{P(A=0|X)}, while the
#' second gives \eqn{P\left(A=1| X\right)}{P(A=1|X)}.
#'
#' @seealso \code{\link{fast_HMM}}
#'
#' @examples
#' p <- 3 # Number of states
#' K <- 2 # Dimensionality of the latent space
#'
#' p_init <- rep(1 / K, K)
#' p_trans <- array(runif((p - 1) * K * K), c(p - 1, K, K))
#' # Normalizing the transition probabilities
#' for (j in seq_len(p - 1)) {
#'   p_trans[j, , ] <- p_trans[j, , ] / (matrix(rowSums(p_trans[j, , ]), ncol = 1) %*% rep(1, K))
#' }
#'
#' p_emit <- array(stats::runif(p * 3 * K), c(p, 3, K))
#' # Normalizing the emission probabilities
#' for (j in seq_len(p)) {
#'   p_emit[j, , ] <- p_emit[j, , ] / (matrix(rep(1, 3), ncol = 1) %*% colSums(p_emit[j, , ]))
#' }
#'
#' hmm <- list(pInit = p_init, Q = p_trans, pEmit = p_emit)
#'
#' n <- 2
#' X <- matrix((runif(n * p, min = 0, max = 1) < 0.4) +
#'             (runif(n * p, min = 0, max = 1) < 0.4),
#'             nrow = 2, dimnames = list(NULL, paste0("SNP_", seq_len(p))))
#'
#' cond_prob(X, "SNP_2", hmm, ncores = 1, binary = TRUE)
#'
#' @export
cond_prob <- function(X, target_name, hmm, binary = FALSE, ncores = 1) {
  stopifnot(!is.null(colnames(X)))
  stopifnot(target_name %in% colnames(X))
  stopifnot(setequal(names(hmm), c("pInit", "Q", "pEmit")))

  # Computing the propensity scores with the forward algorithm
  p_obs <- matrix(nrow = nrow(X), ncol = 3)
  X[, target_name] <- 0
  p_obs[, 1] <- forward(X, hmm$pInit, hmm$Q, hmm$pEmit)
  X[, target_name] <- 1
  p_obs[, 2] <- forward(X, hmm$pInit, hmm$Q, hmm$pEmit)
  X[, target_name] <- 2
  p_obs[, 3] <- forward(X, hmm$pInit, hmm$Q, hmm$pEmit)
  p_obs <- t(apply(p_obs, 1, function(x) return(x - matrixStats::logSumExp(x))))

  if (binary) {
    propensity <- cbind(exp(p_obs[, 1]), exp(p_obs[, 2]) + exp(p_obs[, 3]))
  } else {
    propensity <- cbind(exp(p_obs[, 1]) + exp(p_obs[, 2]), exp(p_obs[, 3]))
  }

  return(propensity)
}

#' Fits a HMM to a genotype dataset by calling fastPHASE
#'
#' In this function, we fit the fastPHASE hidden Markov model (HMM) using the EM
#' algorithm. The fastPHASE executable is required to run \code{fast_HMM}. It
#' can be downloaded from the following web page: \url{http://scheet.org/software.html}
#'
#' @param X genotype matrix
#' @param out_path prefix for the fitted parameters filenames. If \code{NULL},
#'   the files are saved in a temporary directory.
#' @param X_filename filename for the fastPHASE-formatted genotype file. If
#'   \code{NULL}, the file is created in a temporary directory.
#' @param fp_path path to the fastPHASE executable
#' @param n_state dimensionality of the latent space
#' @param n_iter number of iterations for the EM algorithm
#'
#' @return Fitted parameters of the fastPHASE HMM. They are grouped in a list
#'   with the following fields: \code{pInit} for the initial marginal
#'   distribution, the three-dimensional array \code{Q} for the transition
#'   probabilities and finally \code{pEmit}, another three-dimensional array
#'   for the emission probabilities
#'
#' @details Because of the quadratic complexity of the forward algorithm
#' in terms  of the dimensionality of the latent space \code{n_state}, we
#' recommend setting this parameter to 12. Choosing a higher number does
#' not result in a dramatic increase of performance. An optimal
#' choice for the number of iterations for the EM algorithm  is between 20
#' and 25.
#'
#' @references Scheet, P., & Stephens, M. (2006). A fast and flexible
#' statistical model for large-scale population genotype data: applications
#' to inferring missing genotypes and haplotypic phase. American Journal of
#' Human Genetics, 78(4), 629–644.
#'
#' @examples
#' \donttest{
#' p <- 50
#' n <- 100
#' genotypes <- matrix((runif(n * p, min = 0, max = 1) < 0.5) +
#'             (runif(n * p, min = 0, max = 1) < 0.5),
#'             nrow = n, dimnames = list(NULL, paste0("SNP_", seq_len(p))))
#'
#' hmm <- fast_HMM(genotypes, fp_path = "/path/to/fastPHASE",
#'                 n_state = 4, n_iter = 10)
#' }
#'
#' @export
fast_HMM <- function(X, out_path = NULL, X_filename = NULL, fp_path = "bin/fastPHASE",
                     n_state = 12, n_iter = 25) {
  if (!file.exists(fp_path)) {
    stop("Please download the fastPHASE executable to the indicated fp_path")
  }

  # Fitting fastPHASE Hidden Markov Model
  Xinp_file <- SNPknock::writeXtoInp(X, out_file = X_filename)
  fp_out_path <- SNPknock::runFastPhase(fp_path, Xinp_file,
    K = n_state, numit = n_iter, out_path = out_path
  )

  # Loading the fitted Hidden Markov Model
  r_file <- paste(fp_out_path, "_rhat.txt", sep = "")
  theta_file <- paste(fp_out_path, "_thetahat.txt", sep = "")
  alpha_file <- paste(fp_out_path, "_alphahat.txt", sep = "")
  char_file <- paste(fp_out_path, "_origchars", sep = "")

  hmm <- SNPknock::loadHMM(
    r_file = r_file, theta_file = theta_file,
    alpha_file = alpha_file, char_file = char_file,
    compact = FALSE
  )

  return(hmm)
}
