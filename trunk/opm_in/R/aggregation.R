
################################################################################
################################################################################
#
# Curve parameter estimation
#


#' @title Spline options
#' @description Function to set up spline options which can be passed to
#'   \code{\link{do_aggr}}. %and \code{\link{fit_spline}}.
#'
#' @param type Character scalar. Specifies the spline type which should be
#'   fitted. This can be either thin plate splines (\kbd{tp.spline}), penalised
#'   B-splines (i.e, P-splines \kbd{p.spline}) or smoothing splines
#'   (\kbd{smooth.spline}).
#' @param knots Integer scalar. Determines the number of knots. Per default, the
#'   number of knots is chosen adaptively to the number of unique observations.
#'   The default number also depends on the spline \code{type}.
#' @param gamma Integer scalar. Specifies a constant multiplier to inflate the
#'   degrees of freedom in the \code{"GCV"} \code{method} to increase
#'   penalisation of models that are too close to the data and thus not
#'   smooth enough.
#' @param est.method Character scalar. The smoothing parameter estimation
#'   method. Currently, only \code{"REML"}, code{"ML"} and \code{"GCV"} are
#'   supported. This argument is ignored for \code{type = "smooth.spline"}. For
#'   details see \code{\link[mgcv]{gam}} and \code{\link[mgcv]{gamm}}
#'   (see package \pkg{mgcv}).
#' @param s.par list. Further arguments to be passed to the smoother
#'   \code{\link[mgcv]{s}} (see package \pkg{mgcv}). Note that the \pkg{mgcv}
#'   options \code{k} and \code{bs} are specified using \code{type} and
#'   \code{knots} in \pkg{opm}.
#' @param correlation An optional \code{"corStruct"} object (see the help topic
#'   \code{corClasses} in the \pkg{nlme} package) as used to define correlation
#'   structures in package \pkg{nlme}. For better coverage of confidence
#'   intervals and slightly improved spline fits it is advised to use an AR
#'   process of order 1 or 2. However, this correction for auto-correlated error
#'   terms results in increased run time.
#' @param save.models Should the models be saved (on the disk) for further
#'   inspections and plotting?
#' @param filename File name of the models. Per default a name is auto-generated
#'   based on date and time. The file is always generated in the current working
#'   directory.
#' @param ... Additional arguments to be passed to \code{\link[mgcv]{gam}} or
#'   \code{\link{smooth.spline}}.
#' @return List of options.
#'
#' @keywords misc
#' @family aggregation-functions
#' @author Benjamin Hofner
#' @export
#'
set_spline_options <- function(type = c("tp.spline",
    "p.spline", "smooth.spline"),
    knots = NULL, gamma = 1, est.method = c("REML", "ML", "GCV"), s.par = NULL,
    correlation = NULL, save.models = FALSE, filename = NULL, ...) {

  if (!missing(...))
    warning(sQuote("..."), " currently not passed to fitting functions")
  type <- match.arg(type)
  class <- ifelse(type == "tp.spline", "tp",
    ifelse(type == "p.spline", "psp", "smooth.spline"))

  method <- match.arg(est.method)
  if (est.method == "ML" && is.null(correlation))
    stop(sQuote(paste0("est.method = ", dQuote("ML"))), " can only be used if ",
      sQuote("correlation"), " is specified")
  if (est.method == "GCV" && !is.null(correlation))
    stop(sQuote(paste0("est.method = ", dQuote("GCV"))),
      " can only be used if no ", sQuote("correlation"), " is specified")
  if (type == "smoothing-splines" && !is.null(s.par))
    warning(sQuote("s.par"), " ignored if ",
      sQuote('type = "smoothing-splines"'))
  if (!is.null(filename) && !save.models) {
    save.models <- TRUE
    warning(sQuote("filename"), " specified, ", sQuote("save.models"),
      " set to TRUE")
  }
  list(type = type, knots = knots, gamma = gamma, est.method = method,
    s.par = s.par, correlation = correlation, save.models = save.models,
    filename = filename, class = class, ...)
}


################################################################################


#' Aggregate kinetics using curve-parameter estimation
#'
#' Aggregate the kinetic data using curve-parameter estimation, i.e. infer
#' parameters from the kinetic data stored in an \code{\link{OPM}} object using
#' either the \pkg{grofit} package or the built-in method. Optionally include
#' the aggregated values in a novel \code{\link{OPMA}} object together with
#' previously collected information.
#'
#' @param object \code{\link{OPM}}, \code{\link{OPMS}} or \code{\link{MOPMX}}
#'   object or matrix as output by \code{\link{measurements}}, i.e. with the
#'   time points in the first columns and the measurements in the remaining
#'   columns (there must be at least two). For deviations from this scheme see
#'   \code{time.pos} and \code{transposed}.
#' @param boot Integer scalar. Number of bootstrap replicates used to estimate
#'   95-percent confidence intervals (\acronym{CI}s) for the parameters. Set
#'   this to zero to omit bootstrapping, resulting in \code{NA} entries for the
#'   \acronym{CI}s. Note that under the default settings of the matrix method
#'   for \code{as.pe}, bootstrapping is also necessary to obtain the point
#'   estimate.
#' @param verbose Logical scalar. Print progress messages?
#' @param cores Integer scalar. Number of cores to use. Setting this to a value
#'   larger than \code{1} requires that \code{mclapply} from the \pkg{parallel}
#'   package can be run with more than 1 core, which is impossible under
#'   Windows. The \code{cores} argument has no effect if \kbd{opm-fast} is
#'   chosen (see below). If \code{cores} is zero or negative, the overall number
#'   of cores on the system as determined by \code{detectCores} from the
#'   \pkg{parallel} package is used after addition of the original \code{cores}
#'   argument. For instance, if the system has eight cores, \code{-1} means
#'   using seven cores.
#' @param options List. For its use in \pkg{grofit} mode, see
#'   \code{grofit.control} in that package. The \code{boot} and \code{verbose}
#'   settings, as the most important ones, are added separately (see above). The
#'   verbose mode is not very useful in parallel processing. With \code{method}
#'   \code{"splines"}, options can be specified using the function
#'   \code{\link{set_spline_options}}.
#' @param method Character scalar. The aggregation method to use. Currently
#'   only the following methods are supported:
#'   \describe{
#'     \item{splines}{Fit various splines (smoothing splines and P-splines from
#'     \pkg{mgcv} and smoothing splines via \code{smooth.spline}) to
#'     \acronym{PM} data. Recommended.}
#'     \item{grofit}{The \code{grofit} function in the eponymous package, with
#'     spline fitting as default.}
#'     \item{opm-fast}{The native, faster parameter estimation implemented in
#'     the matrix method. This will only yield two of the four parameters, the
#'     area under the curve and the maximum height. The area under the curve is
#'     estimated as the sum of the areas given by the trapezoids defined by each
#'     pair of adjacent time points. The maximum height is just the result of
#'     \code{max}. By default the median of the bootstrap values is used as
#'     point estimate. For details see \code{as.pe}.}
#'   }
#' @param plain Logical scalar. If \code{TRUE}, only the aggregated values are
#'   returned (as a matrix, for details see below). Otherwise they are
#'   integrated in an \code{\link{OPMA}} object together with \code{object}.
#' @param logt0 Logical scalar passed to \code{\link{measurements}}.
#' @param what Character scalar. Which parameter to estimate. Currently only two
#'   are supported.
#' @param ci Confidence interval to use in the output. Ignored if \code{boot} is
#'   not positive.
#' @param as.pe Character scalar determining what to output as the point
#'   estimate. Either \kbd{median}, \kbd{mean} or \kbd{pe}; the first
#'   two calculate the point estimate from the bootstrapping replicates, the
#'   third one use the point estimate from the raw data. If \code{boot} is 0,
#'   \code{as.pe} is reset to \kbd{pe}, if necessary, and a warning is
#'   issued.
#' @param ci.type Character scalar determining the way the confidence intervals
#'   are calculated. Either \kbd{norm}, \kbd{basic} or \kbd{perc}; see
#'   \code{boot.ci} from the \pkg{boot} package for details.
#' @param time.pos Character or integer scalar indicating the position of the
#'   column (or row, see next argument) with the time points.
#' @param transposed Character or integer scalar indicating whether the matrix
#'   is transposed compared to the default.
#' @param raw Logical scalar. Return the raw bootstrapping result without
#'   \acronym{CI} estimation and construction of the usually resulting matrix?
#' @param ... Optional arguments passed between the methods or to \code{boot}
#'   from the eponymous package.
#'
#' @export
#' @return If \code{plain} is \code{FALSE}, an \code{\link{OPMA}} object.
#'   Otherwise a numeric matrix of the same structure than the one returned by
#'   \code{\link{aggregated}} but with an additional \sQuote{settings} attribute
#'   containing the (potentially modified) list proved via the \code{settings}
#'   argument, and a \sQuote{method} attribute corresponding to the
#'   \code{method} argument.
#'
#'   The matrix method returns a numeric matrix with three rows (point estimate,
#'   lower and upper \acronym{CI}) and as many columns as data columns (or rows)
#'   in \code{object}. If \code{raw} is \code{TRUE}, it returns an object of the
#'   class \sQuote{boot}.
#'
#' @family aggregation-functions
#' @seealso grofit::grofit parallel::detectCores
#' @keywords smooth
#'
#' @details Behaviour is special if the \code{\link{plate_type}} is one of those
#'   that have to be explicitly set using \code{\link{gen_iii}} and there is
#'   just one point measurement. Because this behaviour is usual for plates
#'   measured either in Generation-III (identification) mode or on a
#'   MicroStation\eqn{\textsuperscript{\texttrademark}}{(TM)}, the point
#'   estimate is simply regarded as \sQuote{A} parameter (maximum height) and
#'   all other parameters are set to \code{NA}.
#'
#'   The \code{\link{OPMS}} method just applies the \code{\link{OPM}} method to
#'   each contained plate in turn; there are no inter-dependencies. The same
#'   holds for the \code{\link{MOPMX}} method.
#'
#'   Note that some spline-fitting methods would crash with constant input data
#'   (horizontal lines instead of curves). As it is not entirely clear that
#'   those input data always represent artefacts, spline-fitting is skipped in
#'   such cases and replaced by reading the maximum height and the area under
#'   the curve directly from the data but setting the slope and the lag phase
#'   to \code{NA}, with a warning.
#'
#'   Examples with \code{plain = TRUE} are not given, as only the return value
#'   is different: Let \code{x} be the normal result of \code{do_aggr()}. The
#'   matrix returned if \code{plain} is \code{TRUE} could then be received using
#'   \code{aggregated(x)}, whereas the \sQuote{method} and the \sQuote{settings}
#'   attributes could be obtained as components of the list returned by
#'   \code{aggr_settings(x)}.
#'
#'   The matrix method quickly estimates the curve parameters \acronym{AUC}
#'   (area under the curve) or A (maximum height). This is not normally directly
#'   called by an \pkg{opm} user but via the other \code{do_aggr} methods.
#'
#'   The aggregated values can be queried for using \code{\link{has_aggr}}
#'   and received using \code{\link{aggregated}}.
#'
#' @references Brisbin, I. L., Collins, C. T., White, G. C., McCallum, D. A.
#'   1986 A new paradigm for the analysis and interpretation of growth data:
#'   the shape of things to come. \emph{The Auk} \strong{104}, 552--553.
#' @references Efron, B. 1979 Bootstrap methods: another look at the jackknife.
#'   \emph{Annals of Statistics} \strong{7}, 1--26.
#' @references Kahm, M., Hasenbrink, G., Lichtenberg-Frate, H., Ludwig, J.,
#'   Kschischo, M. grofit: Fitting biological growth curves with R.
#'   \emph{Journal of Statistical Software} \strong{33}, 1--21.
#' @references Vaas, L. A. I., Sikorski, J., Michael, V., Goeker, M., Klenk
#'   H.-P. 2012 Visualization and curve parameter estimation strategies for
#'   efficient exploration of Phenotype Microarray kinetics. \emph{PLoS ONE}
#'   \strong{7}, e34846.
#'
#' @examples
#'
#' # OPM method
#'
#' # Run a fast estimate of A and AUC without bootstrapping
#' copy <- do_aggr(vaas_1, method = "opm-fast", boot = 0,
#'   options = list(as.pe = "pe"))
#' aggr_settings(vaas_1)
#' aggr_settings(copy)
#' stopifnot(has_aggr(vaas_1), has_aggr(copy))
#'
#' # Compare the results to the ones precomputed with grofit
#' # (1) A
#' a.grofit <- aggregated(vaas_1, "A", ci = FALSE)
#' a.fast <- aggregated(copy, "A", ci = FALSE)
#' plot(a.grofit, a.fast)
#' stopifnot(cor.test(a.fast, a.grofit)$estimate > 0.999)
#' # (2) AUC
#' auc.grofit <- aggregated(vaas_1, "AUC", ci = FALSE)
#' auc.fast <- aggregated(copy, "AUC", ci = FALSE)
#' plot(auc.grofit, auc.fast)
#' stopifnot(cor.test(auc.fast, auc.grofit)$estimate > 0.999)
#'
#' \dontrun{ # Without confidence interval (CI) estimation
#'   x <- do_aggr(vaas_1, boot = 0, verbose = TRUE)
#'   aggr_settings(x)
#'   aggregated(x)
#'
#'   # Calculate CIs with 100 bootstrap (BS) replicates, using 4 cores
#'   # (do not try to use > 1 core on Windows)
#'   x <- do_aggr(vaas_1, boot = 100, verbose = TRUE, cores = 4)
#'   aggr_settings(x)
#'   aggregated(x)
#' }
#'
#' # matrix method
#' (x <- do_aggr(measurements(vaas_1)))[, 1:3]
#' stopifnot(identical(dim(x), c(3L, 96L)))
#'
setGeneric("do_aggr", function(object, ...) standardGeneric("do_aggr"))

setMethod("do_aggr", "OPM", function(object, boot = 0L, verbose = FALSE,
    cores = 1L, options = if (identical(method, "splines"))
      set_spline_options()
    else
      list(), method = "splines", plain = FALSE, logt0 = FALSE) {

  # Convert to OPMA
  integrate_in_opma <- function(object, result) {
    items <- c(METHOD, OPTIONS, SOFTWARE, VERSION)
    settings <- attributes(result)[items]
    for (item in items)
      attr(result, item) <- NULL
    new(Class = "OPMA", measurements = measurements(object),
      metadata = metadata(object), csv_data = csv_data(object),
      aggregated = result, aggr_settings = settings)
  }

  # Add our own changes of the default
  make_grofit_control <- function(verbose, boot, add) {
    result <- grofit.control()
    orig.class <- class(result)
    result <- insert(unclass(result), interactive = FALSE,
      suppress.messages = !verbose, fit.opt = "s", nboot.gc = boot,
      .force = TRUE)
    result <- insert(result, as.list(add), .force = TRUE)
    class(result) <- orig.class
    result
  }

  run_grofit <- function(time, data, control) {
    extract_curve_params(grofit(time = time, data = data,
      ec50 = FALSE, control = control))
  }

  run_mgcv <- function(x, y, data, options, boot) {
    mod <- fit_spline(y = y, x = x, data = data, options = options)
    if (boot > 0L) {
      ## draw bootstrap sample
      folds <- rmultinom(boot, nrow(data), rep(1 / nrow(data), nrow(data)))
      res <- lapply(seq_len(boot),
        function(i) {
          fit_spline(y = y, x = x, data = data, options = options,
            weights = folds[, i])
      })
      class(res) <- "splines_bootstrap"
      params <- as.vector(summary(res))
      return(list(params = params, model = mod, bootstrap = res))
    }
    list(params = extract_curve_params(mod), model = mod)
  }

  copy_A_param <- function(x) {
    map <- unlist(map_param_names(opm.fast = TRUE))
    result <- matrix(data = NA_real_, nrow = length(map), ncol = length(x),
      dimnames = list(unname(map), names(x)))
    result[map[["A.point.est"]], ] <- x
    result
  }

  if (anyDuplicated.default(hours(object, "all")))
    warning("duplicate time points are present, which makes no sense")

  if (L(cores) <= 0L) {
    cores <- detectCores() + cores
    if (cores <= 0L)
      stop("attempt to use <1 computational core")
  }

  if (dim(object)[1L] < 2L && (plate_type(object) %in% SPECIAL_PLATES ||
      custom_plate_is(plate_type(object)))) {

    result <- copy_A_param(well(object))
    attr(result, METHOD) <- "shortcut"
    attr(result, OPTIONS) <- list(boot = boot,
      preceding_transformation = "none")

  } else {

    case(method <- match.arg(method, KNOWN_METHODS$aggregation),

      grofit = {
        control <- make_grofit_control(verbose, boot, add = options)
        grofit.time <- to_grofit_time(object)
        grofit.data <- to_grofit_data(object, logt0)
        result <- mclapply(X = as.list(seq_len(nrow(grofit.data))),
          FUN = function(row) {
            run_grofit(grofit.time[row, , drop = FALSE],
              grofit.data[row, , drop = FALSE], control)
          }, mc.cores = cores)
        result <- do.call(cbind, result)
        attr(result, OPTIONS) <- unclass(control)
      },

      `opm-fast` = {
        options <- insert(as.list(options), boot = boot, .force = FALSE)
        mat <- measurements(object, , logt0)
        result <- rbind(
          do.call(do_aggr, c(list(object = mat, what = "AUC"), options)),
          do.call(do_aggr, c(list(object = mat, what = "A"), options)),
          matrix(nrow = 6L, ncol = ncol(mat) - 1L, data = NA_real_)
        )
        rownames(result)[7L:9L] <- sub("^[^.]+", "lambda",
          rownames(result)[1L:3L], FALSE, TRUE)
        rownames(result)[10L:12L] <- sub("^[^.]+", "mu",
          rownames(result)[1L:3L], FALSE, TRUE)
        map <- map_param_names(opm.fast = TRUE)
        result <- result[names(map), , drop = FALSE]
        rownames(result) <- as.character(map)
        attr(result, OPTIONS) <- options
      },

      splines = {
        ## extract data
        data <- as.data.frame(measurements(object, , logt0))
        ## get well names
        wells <- wells(object)
        indx <- as.list(seq_len(length(wells)))
        result <- mclapply(X = indx,
          FUN = function(i) {
            run_mgcv(x = HOUR, y = wells[i], data = data, options = options,
              boot = boot)
          }, mc.cores = cores)
        options <- insert(as.list(options), boot = boot)

        if (options$save.models) {
            opm_models <- lapply(result, `[[`, "model")
            if (boot > 0L) {
              opm_bootstrap <- lapply(result, `[[`, "bootstrap")
            } else {
              opm_bootstrap <- NA
            }
            names(opm_models) <- wells
            class(opm_models) <- "opm_models"
            if (is.null(options$filename))
              options$filename <- paste0("opm_models_",
                format(Sys.time(), "%Y-%m-%d_%H:%M:%S"), ".RData")
            save("opm_models", "opm_bootstrap", file = options$filename)
            cat("Models saved as 'opm_models' on disk in file\n  ",
              getwd(), "/", options$filename, "\n\n", sep = "")
        }
        result <- sapply(result, `[[`, "params")
        rn <- rownames(result)
        result <- matrix(unlist(result),
          ncol = ncol(result), nrow = nrow(result))
        rownames(result) <- rn
        ## attach bootstrap CIs if necessary
        if (boot <= 0L)
          result <- rbind(result, matrix(NA, nrow = 8L, ncol = ncol(result)))
        ## dirty hack:
        map <- map_param_names(opm.fast = TRUE)
        rownames(result) <- as.character(map)
        colnames(result) <- wells
        attr(result, OPTIONS) <- unclass(options)
      }

    )

    attr(result, METHOD) <- method
    attr(result, OPTIONS)$preceding_transformation <- if (logt0)
        "logt0"
      else
        "none"

  }

  tmp <- opm_string(version = TRUE)
  attr(result, SOFTWARE) <- tmp[[1L]]
  attr(result, VERSION) <- tmp[[2L]]

  if (L(plain))
    return(result)
  integrate_in_opma(object, result)

}, sealed = SEALED)

setMethod("do_aggr", "OPMS", function(object, ...) {
  object@plates <- lapply(X = object@plates, FUN = do_aggr, ...)
  object
}, sealed = SEALED)

setMethod("do_aggr", "MOPMX", function(object, ...) {
  object@.Data <- lapply(X = object@.Data, FUN = do_aggr, ...)
  object
}, sealed = SEALED)

setMethod("do_aggr", "matrix", function(object, what = c("AUC", "A"),
    boot = 100L, ci = 0.95, as.pe = "median", ci.type = "norm",
    time.pos = 1L, transposed = FALSE, raw = FALSE, ...) {
  LL(time.pos, boot, ci, transposed, raw)
  if (transposed)
    object <- t(object)
  y <- object[, time.pos]
  object <- object[, -time.pos, drop = FALSE]
  object.colnames <- colnames(object)
  ## i arguments are required by boot
  case(what <- match.arg(what),
    A = boot_fun <- function(x, i) apply(x[i, , drop = FALSE], 2L, max),
    AUC = {
      n.obs <- nrow(object)
      y <- y[-1L] - y[-n.obs]
      object <- 0.5 * (object[-1L, , drop = FALSE] +
        object[-n.obs, , drop = FALSE])
      boot_fun <- function(x, i) colSums(x[i, , drop = FALSE] * y[i])
    }
  )
  result <- boot(data = object, statistic = boot_fun, R = boot, ...)
  if (raw)
    return(result)
  result <- pe_and_ci(result, ci = ci, as.pe = as.pe, type = ci.type,
    fill.nas = what == "A")
  colnames(result) <- object.colnames
  rownames(result) <- paste(what, rownames(result), sep = ".")
  result
}, sealed = SEALED)


################################################################################



