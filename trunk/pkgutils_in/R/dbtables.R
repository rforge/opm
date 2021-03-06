

################################################################################
################################################################################
#
# DBTABLES class definitions and associated methods.
#


#' \code{DBTABLES} class
#'
#' This virtual class is intended for holding, in each slot, a data frame that
#' can be written to (or read from) a table in a relational database.
#'
#' @details
#' The idea behind this class is to store the tables that are dependent on each
#' other via foreign keys, in order. Based on a simple naming convention,
#' methods check the supposed primary and the foreign keys (cross references) of
#' the tables.
#'
#' Primary keys must be present in a column called \sQuote{id}, which must not
#' contain duplicates. Columns with foreign keys must be named like
#' \code{paste0(x, "_id")} and then refer to the column \sQuote{id} in a
#' preceding slot named \code{paste0(x, "s")}. Irregular plurals are not
#' currently understood. The two columns must be set-equal.
#'
#' For using another naming scheme for the keys, at least on of the methods
#' \code{\link{pkeys}} and \code{\link{fkeys}} has to be overwritten in a child
#' class, but none of the other methods. The same holds if slots should be
#' included that are not treated as data base tables. \code{\link{split}} might
#' then also need to be overwritten to not ignore these other slots when
#' creating new objects of the class.
#'
#' For the methods of \code{DBTABLES}, see \code{\link{DBTABLES-methods}}.
#' @name DBTABLES-class
#' @docType class
#' @export
#' @aliases DBTABLES
#' @seealso methods::Methods
#' @family dbtables
#' @keywords methods classes
#'
setClass("DBTABLES",
  contains = "VIRTUAL",
  sealed = SEALED
)


################################################################################


#' Methods for \code{DBTABLES} objects
#'
#' Return or check the supposed primary and foreign keys in a
#' \code{\link{DBTABLES}} object, or show, traverse, combine, or split such
#' objects.
#'
#' @param object \code{\link{DBTABLES}} object.
#' @param x \code{\link{DBTABLES}} object.
#' @param data \code{\link{DBTABLES}} object.
#' @param decreasing Logical scalar. If missing, \code{FALSE} is used instead.
#' @param start Numeric vector or \code{NULL}. If a numeric vector and named,
#'   the names must be the slot names; otherwise these are inserted, in order.
#'   Each value of \code{start} defines an new starting point (minimum) for the
#'   primary key in the respective table. \code{update} takes care that the
#'   foreign keys referring to this table are modified in the same way.
#'
#'   If \code{NULL}, \code{start} is set to a vector that causes all output
#'   primary keys to start at 1. This can be used to revert a previous call of
#'   \code{update}.
#' @param recursive Logical scalar passed from \code{c} as \code{drop} argument
#'   to \code{update}. Also causes \code{update} to be applied to \code{x} (and
#'   not only to the elements of \code{...}, if any).
#' @param f Missing or (list of) factor(s) that fit(s) to the dimensions of the
#'   first table returned by. If missing, the primary key of this table is used.
#' @param drop For \code{update}, a logical scalar that indicates whether or not
#'   the row names of all tables should be set to \code{NULL}.
#'
#'   For \code{split}, \code{drop} is either missing or a logical scalar.
#'   \code{TRUE} is the default. If so, after splitting, \code{update} is
#'   applied to each \code{\link{DBTABLES}} object that is an element of the
#'   resulting list, with \code{start} set to \code{NULL} and \code{drop} set to
#'   \code{TRUE}.
#' @param INDICES If \code{do_inline} is \code{FALSE}, a vector used for
#'   selecting a subset of the tables and modifying their order (which might not
#'   make sense, see  \code{\link{DBTABLES}}). Otherwise usually a vector of
#'   primary keys for the first table. Selection of rows from subsequent tables
#'   works via the defined foreign keys. Thus, used for querying for data slots
#'   for a novel \code{\link{DBTABLES}} with \code{FUN}.
#' @param FUN Function to be applied to each table in turn. If \code{do_inline}
#'   is \code{FALSE}, it should accept a character scalar (name of a table) a
#'   data frame (this table) and as the first two (unnamed) arguments.
#'
#'   If \code{do_inline} is \code{TRUE} and \code{simplify} is \code{FALSE},
#'   \code{FUN} should accept three first arguments (in addition to those in
#'   \code{...}, if any), in order: the name of a table (database table or data
#'   frame), the name of a column in that table, and a vector of numeric indexes
#'   to match that column. It should return a data frame with all matched rows.
#'
#'   If \code{do_inline} is \code{TRUE} and \code{simplify} is \code{TRUE},
#'   \code{FUN} should accept a character scalar (\acronym{SQL} statement) as
#'   single first argument in addition to those in \code{...}, and use this to
#'   retrieve columns from a database table. The generated \acronym{SQL} uses
#'   double-quoting for the table and column identifiers and single-quoting for
#'   the query values (starting with \code{INDICES}) unless they are numeric.
#' @param ... Objects of the same class as \code{x} for \code{c}, optional
#'   further arguments of \code{FUN} for \code{by}.
#' @param do_map Optional vector for mapping the slot names in \code{data}
#'   before passing them to \code{FUN}.
#' @param do_inline Logical scalar indicating how \code{FUN} should be used and
#'   which kind of return value should be produced.  See \code{FUN} for details.
#' @param do_quote Character scalar or function used for generating
#'   \acronym{SQL} identifiers. If a function, used directly; otherwise used
#'   as quote character (to be doubled within the character string).
#' @param simplify Logical scalar. If \code{do_inline} is \code{FALSE}, this
#'   argument indicates whether \acronym{SQL} should be generated and passed to
#'   \code{FUN}, see above. If \code{do_inline} is \code{TRUE}, \code{simplify}
#'   determines the second argument passed to \code{FUN}: if \code{TRUE}, the
#'   name of the primary \acronym{ID} column of the database table is used, if
#'   \code{FALSE} the according data frame contained in \code{data} is passed.
#'   If missing, \code{do_inline} is used as default for \code{simplify}.
#' @return
#'   \code{pkeys} yields a character vector with the (expected) name of
#'   the primary key column for each table. \code{fkeys} returns a matrix
#'   that describes the (expected) relations between the tables.
#'
#'   \code{fkeys_valid} and \code{pkeys_valid} return \code{TRUE}
#'   if successful and a character vector describing the problems otherwise.
#'   These functions can thus be used as \code{validity} argument of
#'   \code{setClass}.
#'
#'   \code{summary} creates an S3 object that nicely prints to the screen (and
#'   is used by \code{show}).
#'
#'   \code{length} returns the number of rows of the data frame in the slot
#'   defined by the first entry of \code{fkeys}.
#'
#'   \code{head} and \code{tail} return the minimum and maximum available
#'   primary key, respectively, for all contained tables.
#'
#'   \code{sort} sorts all tables by their primary keys and returns an object
#'   of the same class.
#'
#'   \code{update} and \code{c} return an object of the same class than
#'   \code{object} and \code{x}, respectively. \code{c} runs \code{update} on
#'   all objects in \code{...} to yield overall unique IDs and then runs
#'   \code{rbind} on all tables.
#'
#'   \code{split} uses \code{f} for splitting the first table returned by
#'   \code{pkeys} and then proceeds by accordingly splitting the tables
#'   that refer to it. \code{c} can be used to get the original object back.
#'
#'   \code{by} returns the result of \code{FUN} or \code{INDICES} as a list or
#'   other kind of object, depending on \code{simplify},  if \code{do_inline}
#'   is \code{TRUE}.
#'
#'   If  \code{do_inline} is \code{FALSE}, \code{by} creates a novel
#'   \code{DBTABLES} object. It starts with passing \code{INDICES} as indexes
#'   (optionally within an \acronym{SQL} statement) to \code{FUN}, which should
#'   yield a data frame to be inserted as first table. Further \code{INDICES}
#'   arguments are generated using the information returned by \code{fkeys} to
#'   fill the object. Child classes might need to define a prototype with data
#'   frames that might be empty but already contain the column naming that
#'   defines the cross references.
#'
#' @name DBTABLES-methods
#' @seealso methods::setClass
#' @family dbtables
#' @keywords database
#' @examples
#'
#' # example class, with 'results' referring to 'experiments'
#' setClass("myclass",
#'   contains = "DBTABLES",
#'   slots = c(experiments = "data.frame", results = "data.frame"))
#'
#' x <- new("myclass",
#'   experiments = data.frame(id = 3:1, researcher = "Jane Doe"),
#'   results = data.frame(id = 1:5, experiment_id = c(1L, 3L, 2L, 1L, 3L),
#'     type = c("A", "B", "A", "B", "A"), value = runif(5)))
#'
#' summary(x)
#' length(x) # not the number of slots
#' pkeys(x)
#' fkeys(x) # NA entries are used for table without foreign keys
#'
#' # conduct some checks
#' stopifnot(fkeys_valid(x), pkeys_valid(x), length(x) == 3)
#' stopifnot(anyNA(fkeys(x)), !all(is.na(fkeys(x))))
#'
#' # originally the primary keys are not in order here
#' (y <- sort(x))
#' slot(y, "experiments")
#' slot(y, "results")
#' stopifnot(!identical(x, y))
#'
#' # get first and last primary keys for each table
#' head(x)
#' tail(x)
#' stopifnot(head(x) == 1, tail(x) >= head(x))
#'
#' # modify the primary keys
#' start <- 3:4 # one value per table
#' y <- update(x, start)
#' head(y)
#' tail(y)
#' stopifnot(head(y) == start, tail(y) > start)
#' stopifnot(fkeys_valid(y), pkeys_valid(y)) # must still be OK
#' (y <- update(y, NULL))
#' head(y)
#' tail(y)
#' stopifnot(head(y) == 1, tail(y) > 1)
#' stopifnot(fkeys_valid(y), pkeys_valid(y))
#'
#' # split the data
#' (y <- split(x))
#' stopifnot(sapply(y, length) == 1)
#' stopifnot(sapply(y, fkeys_valid), sapply(y, pkeys_valid))
#'
#' # combine data again
#' (y <- do.call(c, y))
#' stopifnot(length(y) == length(x), class(x) == class(y))
#' stopifnot(fkeys_valid(y), pkeys_valid(y))
#' ## ids are not necessarily the same than before but still OK
#'
#' # traverse the object
#' (y <- by(x, TRUE, function(a, b) is.data.frame(b), simplify = FALSE))
#' stopifnot(unlist(y), !is.null(names(y)))
#' (z <- by(x, 2:1, function(a, b) is.character(a), simplify = FALSE))
#' stopifnot(unlist(z), names(z) == rev(names(y))) # other order
#' (z <- by(x, 1:2, function(a, b) a, simplify = FALSE,
#'   do_map = c(experiments = "A", results = "B"))) # with renaming
#' stopifnot(unlist(z) == c("A", "B")) # new names passed as 2nd argument to FUN
#'
#' # to illustrate by() in inline mode, we use a function that simply yields
#' # the already present slots
#' col_fun <- function(items, tbl, col, idx) {
#'   tmp <- slot(items, tbl)
#'   tmp[tmp[, col] %in% idx, , drop = FALSE]
#' }
#'
#' (y <- by(x, slot(x, "experiments")[, "id"], col_fun, items = x,
#'   do_inline = TRUE, simplify = FALSE))
#' stopifnot(identical(y, x))
#'
#' # select only a subset of the indexes
#' (y <- by(x, c(2L, 1L), col_fun, items = x, do_inline = TRUE,
#'   simplify = FALSE))
#' stopifnot(length(y) == 2)
#'
#' # try a mapping that does not work
#' (y <- try(by(x, c(2L, 1L), col_fun, items = x, simplify = FALSE,
#'   do_inline = TRUE, do_map = c(results = "notthere")), silent = TRUE))
#' stopifnot(inherits(y, "try-error"))
#' ## note that non-matching names would be silently ignored
#'
NULL

#= fkeys DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("fkeys", function(object) standardGeneric("fkeys"))

setMethod("fkeys", "DBTABLES", function(object) {
  pk <- pkeys(object)
  do.call(rbind, lapply(names(pk), function(n) {
      refs <- grep("^\\w+_id$", colnames(slot(object, n)), FALSE, TRUE, TRUE)
      if (length(refs))
        to.tbl <- paste0(substr(refs, 1L, nchar(refs) - 3L), "s")
      else
        refs <- to.tbl <- NA_character_
      cbind(from.tbl = n, from.col = refs, to.tbl = to.tbl, to.col = pk[[n]])
    }))
}, sealed = SEALED)

#= pkeys DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("pkeys", function(object) standardGeneric("pkeys"))

setMethod("pkeys", "DBTABLES", function(object) {
  x <- slotNames(object)
  structure(.Data = rep.int("id", length(x)), names = x)
}, sealed = SEALED)

#= fkeys_valid DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("fkeys_valid",
  function(object) standardGeneric("fkeys_valid"))

setMethod("fkeys_valid", "DBTABLES", function(object) {
  join <- function(x) paste0(unique.default(x), collapse = " ")
  x <- fkeys(object)[-1L, , drop = FALSE]
  bad <- is.na(x[, "from.col"])
  errs <- sprintf("no references in slot '%s'", x[bad, "from.tbl"])
  x <- x[!bad, , drop = FALSE]
  bad <- apply(x, 1L, function(row) tryCatch(expr = {
      other <- slot(object, row["to.tbl"])[, row["to.col"]]
      self <- slot(object, row["from.tbl"])[, row["from.col"]]
      if (!all(self %in% other))
        stop(sprintf("dead references: %s <=> %s", join(self), join(other)))
      if (!all(other %in% self))
        stop(sprintf("superfluous ids: %s <=> %s", join(other), join(self)))
      NA_character_
    }, error = conditionMessage))
  if (any(really <- !is.na(bad)))
    errs <- c(errs, sprintf("problem in %s/%s: %s",
      x[really, "from.tbl"], x[really, "to.tbl"], bad[really]))
  if (length(errs))
    errs
  else
    TRUE
}, sealed = SEALED)

#= pkeys_valid DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("pkeys_valid",
  function(object) standardGeneric("pkeys_valid"))

setMethod("pkeys_valid", "DBTABLES", function(object) {
  pk <- pkeys(object)
  result <- mapply(function(slotname, colname) tryCatch(expr = {
      if (anyDuplicated.default(slot(object, slotname)[, colname]))
        stop("non-unique IDs")
      NA_character_
    }, error = conditionMessage), names(pk), pk)
  if (length(result <- result[!is.na(result)]))
    sprintf("problem in %s: %s", names(result), result)
  else
    TRUE
}, sealed = SEALED)

#= summary DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("summary")

setMethod("summary", "DBTABLES", function(object) {
  structure(.Data = list(Class = class(object), Size = length(object),
    Crossrefs = fkeys(object)), class = "DBTABLES_Summary")
}, sealed = SEALED)

#= show DBTABLES-methods

setMethod("show", "DBTABLES", function(object) {
  print(summary(object))
}, sealed = SEALED)

#= length DBTABLES-methods

setMethod("length", "DBTABLES", function(x) {
  nrow(slot(x, names(pkeys(x))[1L]))
}, sealed = SEALED)

#= head DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("head")

setMethod("head", "DBTABLES", function(x) {
  pk <- pkeys(x)
  mapply(function(slotname, colname) min(slot(x, slotname)[, colname]),
    names(pk), pk)
}, sealed = SEALED)

#= tail DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("tail")

setMethod("tail", "DBTABLES", function(x) {
  pk <- pkeys(x)
  mapply(function(slotname, colname) max(slot(x, slotname)[, colname]),
    names(pk), pk)
}, sealed = SEALED)

#= sort DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("sort")

setMethod("sort", c("DBTABLES", "missing"), function(x, decreasing) {
  sort(x, FALSE)
}, sealed = SEALED)

setMethod("sort", c("DBTABLES", "logical"), function(x, decreasing) {
  sort_by_id <- function(x, idx) x[sort.list(x[, idx], NULL, TRUE,
    decreasing), , drop = FALSE]
  for (i in seq_along(pk <- pkeys(x)))
    slot(x, tn) <- sort_by_id(slot(x, tn <- names(pk)[i]), pk[i])
  x
}, sealed = SEALED)

#= update DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("update")

setMethod("update", "DBTABLES", function(object, start, drop = TRUE) {
  unrowname <- function(x) {
    rownames(x) <- NULL
    x
  }
  reset <- function(x, where, start) {
    if (add <- start - min(x[, where]))
      x[, where] <- x[, where] + add
    x
  }
  pk <- pkeys(object)
  if (is.null(start)) {
    start <- rep.int(1L, length(pk))
    names(start) <- names(pk)
  } else {
    if (anyNA(start))
      stop("'start' contains missing values")
    if (is.null(names(start)))
      names(start) <- names(pk)[seq_along(start)]
  }
  if (drop)
    for (tn in names(pk))
      slot(object, tn) <- unrowname(slot(object, tn))
  storage.mode(start) <- "integer"
  if (!length(start <- start[!!start]))
    return(object)
  crs <- fkeys(object)
  crs <- crs[!is.na(crs[, "to.tbl"]), , drop = FALSE]
  for (i in seq_along(start)) {
    tn <- names(start)[i]
    slot(object, tn) <- reset(slot(object, tn), pk[[tn]], start[i])
    cr <- crs[crs[, "to.tbl"] == tn, , drop = FALSE]
    for (j in seq_len(nrow(cr))) {
      tn <- cr[j, "from.tbl"]
      slot(object, tn) <- reset(slot(object, tn), cr[j, "from.col"], start[i])
    }
  }
  object
}, sealed = SEALED)

#= c DBTABLES-methods

setGeneric("c")

setMethod("c", "DBTABLES", function(x, ..., recursive = FALSE) {
  if (recursive)
    x <- update(x, NULL, TRUE)
  if (missing(..1))
    return(x)
  klass <- class(x)
  pk <- pkeys(x)
  x <- list(x, ...)
  for (i in seq_along(x)[-1L])
    x[[i]] <- update(x[[i]], tail(x[[i - 1L]]) + 1L, recursive)
  result <- sapply(X = names(pk), simplify = FALSE,
    FUN = function(slotname) do.call(rbind, lapply(x, slot, slotname)))
  do.call(new, c(list(Class = klass), result))
}, sealed = SEALED)

#= split DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("split")

setMethod("split", c("DBTABLES", "missing", "missing"), function(x, f, drop) {
  f <- pkeys(x)[1L]
  split(x, slot(x, names(f))[, f], TRUE)
}, sealed = SEALED)

setMethod("split", c("DBTABLES", "missing", "logical"), function(x, f, drop) {
  f <- pkeys(x)[1L]
  split(x, slot(x, names(f))[, f], drop)
}, sealed = SEALED)

setMethod("split", c("DBTABLES", "ANY", "missing"), function(x, f, drop) {
  split(x, f, TRUE)
}, sealed = SEALED)

setMethod("split", c("DBTABLES", "ANY", "logical"), function(x, f, drop) {
  id2pos <- function(x, i) structure(.Data = rep.int(i, length(x)), names = x)
  get_mapping <- function(x, key, text) {
    if (!is.list(x))
      stop("ordering problem encountered ", paste0(text, collapse = "->"))
    x <- lapply(lapply(x, `[[`, key), unique.default)
    x <- mapply(id2pos, x, seq_along(x), SIMPLIFY = FALSE, USE.NAMES = FALSE)
    unlist(x, FALSE, TRUE)
  }
  class.arg <- list(Class = class(x))
  result <- as.list(pkeys(x))
  result[[1L]] <- split(slot(x, names(result)[1L]), f, TRUE)
  crs <- fkeys(x)
  for (i in seq_along(result)[-1L]) {
    this <- names(result)[i]
    cr <- crs[crs[, "from.tbl"] == this, , drop = FALSE][1L, ]
    mapping <- get_mapping(result[[cr[["to.tbl"]]]], cr[["to.col"]], cr)
    this <- slot(x, this)
    grps <- mapping[as.character(this[, cr[["from.col"]]])]
    result[[i]] <- split(this, grps, TRUE)
  }
  result <- lapply(seq_along(result[[1L]]), function(i) lapply(result, `[[`, i))
  result <- lapply(result, function(x) do.call(new, c(class.arg, x)))
  if (drop)
    result <- lapply(result, update, NULL, TRUE)
  result
}, sealed = SEALED)

#= by DBTABLES-methods

#' @rdname DBTABLES-methods
#' @export
#'
setGeneric("by")

setMethod("by", c("DBTABLES", "ANY", "character", "missing"), function(data,
    INDICES, FUN, ..., do_map = NULL, do_inline = FALSE, do_quote = '"',
    simplify) {
  by(data, INDICES, match.fun(FUN), ..., do_map = do_map, do_inline = do_inline,
    do_quote = do_quote, simplify = do_inline)
}, sealed = SEALED)

setMethod("by", c("DBTABLES", "ANY", "character", "logical"), function(data,
    INDICES, FUN, ..., do_map = NULL, do_inline = FALSE, do_quote = '"',
    simplify) {
  by(data, INDICES, match.fun(FUN), ..., do_map = do_map, do_inline = do_inline,
    do_quote = do_quote, simplify = simplify)
}, sealed = SEALED)

setMethod("by", c("DBTABLES", "ANY", "function", "missing"), function(data,
    INDICES, FUN, ..., do_map = NULL, do_inline = FALSE, do_quote = '"',
    simplify) {
  by(data, INDICES, FUN, ..., do_map = do_map, do_inline = do_inline,
    do_quote = do_quote, simplify = do_inline)
}, sealed = SEALED)

setMethod("by", c("DBTABLES", "ANY", "function", "logical"), function(data,
    INDICES, FUN, ..., do_map = NULL, do_inline = FALSE, do_quote = '"',
    simplify) {

  map_items <- function(x, mapping) {
    if (!length(names(mapping)))
      return(x)
    pos <- match(x, names(mapping), 0L)
    x[found] <- mapping[pos[found <- pos > 0L]]
    x
  }

  sq <- function(x) if (is.numeric(x))
    x
  else
    sprintf("'%s'", gsub("'", "''", x, FALSE, FALSE, TRUE))

  if (is.function(do_quote))
    dq <- do_quote
  else
    dq <- function(x) sprintf(sprintf("%s%%s%s", do_quote, do_quote),
      gsub(do_quote, paste0(do_quote, do_quote), x, FALSE, FALSE, TRUE))

  if (do_inline) {

    get_fun <- if (simplify)
        function(.TBL, .COL, .IDX, ...) FUN(
          sprintf("SELECT * FROM %s WHERE %s;", dq(.TBL),
          paste(dq(.COL), sq(.IDX), sep = " = ", collapse = " OR ")), ...)
      else
        FUN
    pk <- pkeys(data)
    result <- lapply(as.list(pk), as.null)
    result[[1L]] <- as.data.frame(get_fun(
      map_items(names(result)[1L], do_map), pk[1L], INDICES, ...))
    crs <- fkeys(data)
    crs <- crs[!is.na(crs[, "to.tbl"]), , drop = FALSE]
    for (i in seq_len(nrow(crs))) {
      cr <- crs[i, ]
      if (!is.null(result[[cr[["from.tbl"]]]]))
        next
      INDICES <- result[[cr[["to.tbl"]]]][, cr[["to.col"]]]
      result[[cr[["from.tbl"]]]] <- as.data.frame(get_fun(map_items(
        cr[["from.tbl"]], do_map), cr[["from.col"]], INDICES, ...))
    }
    do.call(new, c(list(Class = class(data)), result))

  } else if (simplify) {

    ids <- pkeys(data)[INDICES]
    tns <- map_items(names(ids), do_map)
    mapply(FUN = FUN, tns, ids, MoreArgs = list(...))

  } else {

    tn2 <- map_items(tn1 <- names(pkeys(data))[INDICES], do_map)
    mapply(FUN = FUN, tn2, lapply(tn1, slot, object = data),
      MoreArgs = list(...))

  }

}, sealed = SEALED)


################################################################################

