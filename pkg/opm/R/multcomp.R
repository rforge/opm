setGeneric("opm_mcp",
  function(object, ...) standardGeneric("opm_mcp"))

setMethod("opm_mcp", "MOPMX", function(object, model, linfct = 1L,
    m.type = "glm", rhs = 0, alternative = "two.sided", glht.args = list(),
    ops = "+", output = "mcp", sep = opm_opt("comb.value.join"), ...) {
  object <- extract(object = object, dataframe = NA, sep = sep, ...,
    as.labels = metadata_key(model, FALSE, ops = ops, syntactic = FALSE,
      remove = RESERVED_NAMES[c("well", "value", "parameter")]))
  attr(object, opm_string()) <- list(plate.type = NULL)
  opm_mcp(object = object, model = model, linfct = linfct, ops = ops,
    m.type = m.type, split.at = param_names("split.at"), glht.args = glht.args,
    output = output, sep = sep, rhs = rhs, alternative = alternative)
}, sealed = SEALED)

setMethod("opm_mcp", "OPMS", function(object, model, linfct = 1L,
    m.type = "glm", rhs = 0, alternative = "two.sided", glht.args = list(),
    ops = "+", output = "mcp", sep = opm_opt("comb.value.join"), ...) {
  annotation <- list(plate.type = plate_type(object))
  object <- extract(object = object, dataframe = TRUE, sep = sep, ...,
    as.labels = metadata_key(model, FALSE, ops = ops, syntactic = FALSE,
      remove = RESERVED_NAMES[c("well", "value", "parameter")]))
  attr(object, opm_string()) <- annotation
  opm_mcp(object = object, model = model, linfct = linfct, ops = ops,
    m.type = m.type, split.at = param_names("split.at"), glht.args = glht.args,
    output = output, sep = sep, rhs = rhs, alternative = alternative)
}, sealed = SEALED)

setMethod("opm_mcp", "data.frame", function(object, model, linfct = 1L,
    m.type = c("glm", "lm", "aov"), rhs = 0, alternative = "two.sided",
    glht.args = list(), ops = "+",
    output = c("mcp", "data", "model", "linfct", "contrast"),
    sep = opm_opt("comb.value.join"), split.at = param_names("split.at")) {

  ## helper functions

  convert_model <- function(model, ops) {
    enforce_left_side <- function(f) {
      if (length(f) < 3L) # f must be a formula
        f[[3L]] <- f[[2L]]
      f[[2L]] <- as.name(RESERVED_NAMES[["value"]])
      f
    }
    enforce_left_side(metadata_key(model, TRUE, ops = ops, syntactic = TRUE))
  }

  # Generate all pairs of factor levels for a given data column, considering
  # column joining if applicable. Resulting character vector can be passed to
  # multcomp::mcp().
  level_pairs <- function(spec, column, data, rhs, alternative) {
    spec_to_column_names <- function(spec, joined, column) {
      if (nchar(spec) < 7L)
        spec <- "1"
      else
        spec <- unlist(strsplit(spec, substr(spec, 6L, 6L), TRUE))[-1L]
      if (!all(grepl("^\\d+$", spec, FALSE, TRUE)))
        return(spec)
      if (is.null(joined)) # this would never yield pairs at the moment
        joined <- as.list(structure(.Data = column, names = column))
      joined[[column]][as.integer(spec)]
    }
    pair_indices <- function(x) {
      lastval <- length(nums <- seq_along(x))
      do.call(rbind, lapply(nums[-lastval],
        FUN = function(j) cbind(I = seq.int(j + 1L, lastval), J = j)))
    }
    all_pairs <- function(x, rhs, sign) {
      idx <- pair_indices(x <- unique.default(x))
      sprintf("`%s` - `%s` %s %s", x[idx[, 1L]], x[idx[, 2L]], sign, rhs)
    }
    spec <- spec_to_column_names(spec, attr(data, "joined.columns"), column)
    # this should conserve the 'data[, spec]' factor levels as names
    groups <- split(as.character(data[, column]), data[, spec])
    sign <- case(match.arg(alternative, c("two.sided", "less", "greater")),
      two.sided = "==", less = "<=", greater = ">=")
    result <- unlist(lapply(groups, all_pairs, rhs, sign))
    if (!length(result))
      stop("no pairs found -- are selected factors constant?")
    result
  }

  # Create a Dunnett contrast matrix using 'level' as base, which is hopefully
  # found in the 'column' of 'data'.
  #
  dunnett_with_base <- function(data, column, level) {
    f <- as.factor(data[, column])
    if (grepl("^\\d+$", level, FALSE, TRUE)) {
      base <- as.integer(level)
      if (base > length(levels(f)))
        stop(sprintf("level no. %i does not exist", base))
    } else {
      base <- match(level, levels(f), nomatch = 0L)
      if (!base)
        stop(sprintf("level '%s' does not exist", level))
    }
    multcomp::contrMat(c(table(f)), "Dunnett", base)
  }

  # Convert the 'linfct' argument into its final form. 'model' is needed when
  # getting column names from it if given as positions within the model, 'data'
  # is necessary when computing on factor levels.
  #
  convert_hypothesis_spec <- function(linfct, model, data, rhs, alternative) {
    if (!length(linfct))
      stop("hypothesis definition 'linfct' must not be empty")
    # note that the glht() methods actually dispatch over 'linfct'...
    used.by.glht <- c("mcp", "matrix", "expression", "character", "means")
    if (inherits(linfct, used.by.glht))
      return(linfct)
    if (inherits(linfct, "AsIs")) # created using I()
      return(do.call(multcomp::mcp, as.list(linfct)))
    linfct <- metadata_key(linfct, FALSE)
    if (is.list(linfct))
      result <- names(linfct)
    else if (is.numeric(linfct) || is.logical(linfct)) {
      result <- names(metadata_key(model, FALSE))[linfct]
      names(result) <- names(linfct)
    } else if (is.character(linfct))
      result <- linfct
    else
      stop("invalid object passed as 'linfct' argument")
    if (is.null(names(result)))
      names(result) <- rep(get("contrast.type", OPM_OPTIONS),
        length.out = length(result))
    # At this stage we have a character vector with contrast types as names and
    # column names as values. Names and values are now swapped and then passed
    # as list to multcomp::mcp().
    result <- as.list(structure(.Data = names(result), names = result))
    # Special treatments for special contrast types must be done here.
    if (any(convert <- grepl("^Pairs", result, FALSE, TRUE)))
      result[convert] <- mapply(FUN = level_pairs, spec = result[convert],
        column = names(result)[convert], SIMPLIFY = FALSE,
        MoreArgs = list(data = data, rhs = rhs, alternative = alternative),
        USE.NAMES = FALSE)
    if (any(convert <- grepl("^Dunnett..+", result, FALSE, TRUE)))
      result[convert] <- mapply(FUN = dunnett_with_base,
        level = substr(result, 9L, nchar(result))[convert],
        column = names(result)[convert], MoreArgs = list(data = data),
        SIMPLIFY = FALSE, USE.NAMES = FALSE)
    do.call(multcomp::mcp, result)
  }

  convert_data <- function(object, split.at, model, sep) {
    param.pos <- assert_splittable_matrix(object, split.at)
    # create reshaped data frame and set temporary helper column '_ID' to avoid
    # non-unique values when setting 'row.names'; note according shift of column
    # positions!
    object <- reshape(cbind(`_ID` = seq_len(nrow(object)), object),
      direction = "long",
      idvar = c("_ID", colnames(object)[seq_len(param.pos - 1L)]),
      varying = colnames(object)[seq.int(param.pos + 1L, ncol(object))],
      v.names = RESERVED_NAMES[["value"]],
      timevar = RESERVED_NAMES[["well"]],
      times = colnames(object)[seq.int(param.pos + 1L, ncol(object))])
    rownames(object) <- NULL
    object[, RESERVED_NAMES[["well"]]] <- as.factor(
      object[, RESERVED_NAMES[["well"]]])
    object$`_ID` <- NULL
    # the next step would combine the columns that have not yet been combined
    if (is.list(attr(model, "combine")))
      object <- extract_columns(object, attr(model, "combine"), direct = TRUE,
        sep = sep)
    if (!is.null(joined <- attr(object, "joined.columns"))) {
      names(joined) <- make.names(names(joined))
      joined <- lapply(joined, make.names)
    }
    if (any(isna <- is.na(object[, RESERVED_NAMES[["value"]]])))
      object <- object[!isna, , drop = FALSE]
    colnames(object) <- make.names(colnames(object))
    object
  }

  contrast_matrices <- function(data, linfct, model, rhs, alternative) {
    linfct <- convert_hypothesis_spec(linfct, model, data, rhs, alternative)
    if (!inherits(linfct, "mcp"))
      stop("in 'contrast' mode, 'linfct' must yield an object of class 'mcp'")
    n <- lapply(data[, names(linfct), drop = FALSE], table)
    mapply(multcomp::contrMat, n = n, type = linfct, SIMPLIFY = FALSE)
  }

  # conversions and early returns, if requested
  sep <- check_mcp_sep(sep)
  model <- convert_model(model, ops)
  case(match.arg(output),
    data = return(as(convert_data(object, split.at, model, sep),
      "OPM_MCP_OUT")),
    model = return(model),
    linfct = return(convert_hypothesis_spec(linfct, model,
      convert_data(object, split.at, model, sep), rhs, alternative)),
    contrast = return(contrast_matrices(convert_data(object,
      split.at, model, sep), linfct, model, rhs, alternative)),
    mcp = NULL
  )

  annotation <- attr(object, opm_string())
  object <- convert_data(object, split.at, model, sep)
  linfct <- convert_hypothesis_spec(linfct, model, object, rhs, alternative)

  # fit the linear model according to 'm.type', then run glht()
  model <- do.call(match.arg(m.type), list(formula = model, data = object))
  glht.args <- c(list(model = model, linfct = linfct, rhs = rhs),
    as.list(glht.args))
  if (is.matrix(linfct))
    glht.args$alternative <- alternative
  result <- do.call(glht, glht.args)
  class(result) <- c("opm_glht", oldClass(result))

  attr(result, opm_string()) <- annotation
  result
}, sealed = SEALED)

setGeneric("annotated", function(object, ...) standardGeneric("annotated"))

setMethod("annotated", "OPMA", function(object, what = "kegg", how = "ids",
    output = opm_opt("curve.param"), lmap = NULL, sep = NULL, conc = FALSE) {
  result <- aggregated(object, subset = output, ci = FALSE, full = TRUE,
    in.parens = FALSE, max = 10000L)[1L, ]
  convert_annotation_vector(result, how, what, conc)
}, sealed = SEALED)

setMethod("annotated", "OPMD", function(object, what = "kegg", how = "ids",
    output = opm_opt("curve.param"), lmap = NULL, sep = NULL, conc = FALSE) {
  output <- match.arg(output,
    unlist(map_param_names(plain = TRUE, disc = TRUE)))
  result <- if (output == DISC_PARAM)
    map_values(discretized(object, full = TRUE, in.parens = FALSE,
      max = 10000L), lmap)
  else
    aggregated(object, subset = output, ci = FALSE, full = TRUE,
      in.parens = FALSE, max = 10000L)[1L, ]
  convert_annotation_vector(result, how, what, conc)
}, sealed = SEALED)

setMethod("annotated", "OPMS", function(object, what = "kegg", how = "ids",
    output = opm_opt("curve.param"), lmap = NULL, sep = opm_opt("min.mode"),
    conc = FALSE) {
  output <- match.arg(output,
    unlist(map_param_names(plain = TRUE, disc = TRUE)))
  if (output == DISC_PARAM) { # will crash unless all are discretized
    result <- discretized(object, full = TRUE, in.parens = FALSE, max = 10000L)
    result <- map_values(reduce_to_mode.matrix(result, L(sep), TRUE), lmap)
  } else {
    result <- aggregated(object, subset = output, ci = FALSE, full = TRUE,
      in.parens = FALSE, max = 10000L)
    result <- colMeans(do.call(rbind, result))
  }
  convert_annotation_vector(result, how, what, conc)
}, sealed = SEALED)

setMethod("annotated", "MOPMX", function(object, what = "kegg", how = "ids",
    output = opm_opt("curve.param"), lmap = NULL, sep = opm_opt("min.mode"),
    conc = FALSE) {
  output <- match.arg(output,
    unlist(map_param_names(plain = TRUE, disc = TRUE)))
  if (output == DISC_PARAM) { # will crash unless all are discretized
    result <- discretized(object, full = TRUE, in.parens = FALSE, max = 10000L)
    is.vec <- !vapply(result, is.matrix, 0L)
    result[is.vec] <- lapply(result[is.vec], vector2row)
    result <- collect(x = result, what = "rows", dataframe = FALSE,
      keep.unnamed = TRUE)
    result <- map_values(reduce_to_mode.matrix(result, L(sep), TRUE), lmap)
  } else {
    result <- aggregated(object, subset = output, ci = FALSE, full = TRUE,
      in.parens = FALSE, max = 10000L)
    result <- colMeans(collect(x = unlist(result, FALSE, FALSE), what = "rows",
      dataframe = FALSE, keep.unnamed = TRUE), na.rm = TRUE)
  }
  convert_annotation_vector(result, how, what, conc)
}, sealed = SEALED)

setMethod("annotated", "OPM_MCP_OUT", function(object, what = "kegg",
    how = "ids", output = c("full", "plain"), lmap = NULL, sep = NULL,
    conc = FALSE) {
  alternative <- function(x, y, sep) {
    if (!length(sep) || identical(sep, FALSE))
      return(y)
    if (identical(sep, TRUE))
      return(x)
    if (inherits(sep, "AsIs"))
      paste(y, x, sep = sep)
    else
      paste(x, y, sep = sep)
  }
  result <- object[, RESERVED_NAMES[["value"]]]
  names(result) <- well_to_substrate(as.character(object[,
    RESERVED_NAMES[["well"]]]), attr(object, CSV_NAMES[["PLATE_TYPE"]]))
  result <- convert_annotation_vector(result, how, what, conc)
  case(match.arg(output), plain = return(result), full = NULL)
  if (is.null(dim(result))) {
    cn <- alternative(RESERVED_NAMES[["parameter"]], what, sep)
    suppressWarnings(object[, cn] <- names(result)) # removes the S4 class
    return(object)
  }
  result <- result[, setdiff(colnames(result), RESERVED_NAMES[["value"]]),
    drop = FALSE]
  if (is.matrix(result))
    result <- as.data.frame(result, optional = TRUE, stringsAsFactors = FALSE)
  rownames(result) <- rownames(object)
  cbind(object, result)
}, sealed = SEALED)

setOldClass("opm_glht")

setMethod("annotated", "opm_glht", function(object, what = "kegg", how = "ids",
    output = "numeric", lmap = NULL, sep = opm_opt("comb.value.join"),
    conc = FALSE) {

  # Find (1) full well names within 'opm_glht' objects and (2) substrate names
  # within these full names.
  names_to_substrates <- function(x, sep, plate) {
    # Simple helper function
    prepare_sep <- function(x) {
      x <- check_mcp_sep(x)
      if (x %in% c("^", "\\"))
        x <- paste0("\\", x)
      sprintf("[%s]", x)
    }
    # Extract substrate names (with or w/o well coordinates) from 'Pairs' type
    # names of test results stored in 'opm_glht' objects.
    match_Pairs_type <- function(x, sep) {
      pats <- c(sprintf("^`([^`]+)%s[^`]+`\\s-\\s`\\1%s[^`]+`$", sep, sep),
        sprintf("^`[^`]+?%s([^`]+)`\\s-\\s`[^`]+?%s\\1`$", sep, sep),
        "^`([^`]+)`\\s-\\s`\\1`$")
      for (p in pats)
        if (all(attr(m <- regexpr(p, x, FALSE, TRUE), "match.length") > 0L))
          return(get_partial_match(1L, m, x))
      NULL
    }
    # Same for 'Dunnett' type names
    match_Dunnett_type <- function(x) {
      m <- regexpr("^(.+)\\s-\\s(.+)$", x, FALSE, TRUE)
      if (!all(attr(m, "match.length") > 0L))
        return(NULL)
      result <- lapply(seq_len(2L), get_partial_match, m, x)
      result <- result[!vapply(result, is_constant, NA)]
      case(length(result), NULL, result[[1L]])
    }
    if (length(result <- match_Pairs_type(x, prepare_sep(sep))))
      return(well_to_substrate(result, plate))
    if (length(result <- match_Dunnett_type(x)))
      return(well_to_substrate(result, plate))
    # other patterns to be added here (but currently none of the others are
    # expected to contain substrate names)
    warning("pattern matching of substrates in contrast names did not result")
    rep.int(NA_character_, length(x))
  }

  create_vector <- function(x, how, cutoff, lmap) {
    if (!is.matrix(x))
      stop("expected matrix, got ", class(x))
    if (how == "numeric")
      return(x[, "Estimate"])
    structure(.Data = map_values(case(how,
      downwards = ifelse(x[, "lwr"] > cutoff, FALSE, ifelse(x[, "upr"] < cutoff,
        TRUE, NA)),
      upwards = ifelse(x[, "lwr"] > cutoff, TRUE, ifelse(x[, "upr"] < cutoff,
        FALSE, NA)),
      different = x[, "lwr"] > cutoff | x[, "upr"] < cutoff,
      equal = cutoff > x[, "lwr"] & cutoff < x[, "upr"],
      larger = x[, "lwr"] > cutoff,
      smaller = x[, "upr"] < cutoff
    ), lmap), names = rownames(x), how = how, cutoff = cutoff, lmap = lmap)
  }

  if (is.numeric(L(output))) {
    cutoff <- output
    output <- "different"
  } else if (grepl("^[!=<>,']", output, FALSE, TRUE)) {
    cutoff <- must(as.numeric(substr(output, 2L, nchar(output))))
    output <- c(`!` = "different", `=` = "equal", `<` = "smaller",
      `>` = "larger", `'` = "upwards",
      `,` = "downwards")[[substr(output, 1L, 1L)]]
  } else {
    output <- tolower(output)
    cutoff <- get("threshold", OPM_OPTIONS)
  }
  result <- create_vector(confint(object)$confint, output, cutoff, lmap)
  names(result) <- names_to_substrates(names(result), sep,
    attr(object, opm_string())$plate.type)
  convert_annotation_vector(result, how, what, conc)
}, sealed = SEALED)

