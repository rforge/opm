

################################################################################
################################################################################
#
# Conversion methods
#



setAs("ATOMIC_VALIDATOR", "list", function(from) {
  structure(list(from@what), names = from@how)
})


setAs("list", "ATOMIC_VALIDATOR", function(from) {
  new("ATOMIC_VALIDATOR", how = names(from)[[1L]], what = from[[1L]])
})


setAs("ATOMIC_VALIDATOR", "function", function(from) {
  safe_nchar <- function(x) ifelse(is.na(x), NA_integer_, nchar(x))
  switch(from@how,
    enum = function(x) all(x %in% from@what), # like kwalify
    lower_bound = function(x) all(x >= from@what), # kwalify: 'min'
    min_chars = function(x) all(safe_nchar(x) >= from@what), # kwalify: 'length'
    min_elems = function(x) length(x) >= from@what, # kwalify: 'min-elems'
    max_chars = function(x) all(safe_nchar(x) <= from@what), # kwalify: 'length'
    max_elems = function(x) length(x) <= from@what, # kwalify: 'max-elems'
    pattern = function(x) all(vapply(from@what, grepl, logical(length(x)),
      x = x, perl = TRUE)), # like kwalify
    pattern_fixed = function(x) all(vapply(from@what, grepl, logical(length(x)),
      x = x, fixed = TRUE)),
    pattern_ignoring_case = function(x) all(vapply(from@what, grepl,
      logical(length(x)), x = x, perl = TRUE, ignore.case = FALSE)),
    sorted = function(x) if (from@what)
        !is.unsorted(x)
      else
        is.unsorted(x),
    type = function(x) typeof(x) %in% from@what, # like kwalify
    unique = function(x) if (from@what)
        !any(duplicated(x))
      else
        any(duplicated(x)),
    upper_bound = function(x) all(x <= from@what), # kwalify: 'max'
    function(x) stop(sprintf("uninterpretable entry in 'how' slot: '%s'",
      from@how))
  )
})


################################################################################


setAs("ATOMIC_VALIDATION", "logical",
  function(from) structure(from@result, names = from@how))

## TODO: => list


################################################################################


setAs("ATOMIC_VALIDATORS", "list", function(from) {
  unlist(lapply(from@checks, as, "list"), FALSE, TRUE)
})


setAs("list", "ATOMIC_VALIDATORS", function(from) new("ATOMIC_VALIDATORS",
  checks = mapply(new, how = names(from), what = from, SIMPLIFY = FALSE,
    MoreArgs = list(Class = "ATOMIC_VALIDATOR"), USE.NAMES = FALSE)))


setAs("ATOMIC_VALIDATORS", "ATOMIC_VALIDATIONS", function(from) {
  new("ATOMIC_VALIDATIONS", checks = lapply(from@checks, validator2validation))
})


################################################################################


setAs("ATOMIC_VALIDATIONS", "logical", function(from) {
  vapply(from@checks, as, NA, "logical")
})


setAs("ATOMIC_VALIDATIONS", "ATOMIC_VALIDATORS", function(from) {
  new("ATOMIC_VALIDATORS",
    checks = lapply(from@checks, validation2validator))
})


## TODO: => list


################################################################################


setAs("ELEMENT_VALIDATOR", "list", function(from) {
  c(list(required = from@required),
    unlist(lapply(from@checks, as, "list"), FALSE, TRUE))
})


setAs("list", "ELEMENT_VALIDATOR", function(from) {
  if (pos <- match("required", names(from), 0L)) {
    required <- from[[pos]]
    from <- from[-pos]
  } else {
    required <- FALSE
  }
  new("ELEMENT_VALIDATOR", required = required,
    checks = mapply(new, how = names(from), what = from, SIMPLIFY = FALSE,
      MoreArgs = list(Class = "ATOMIC_VALIDATOR"), USE.NAMES = FALSE))
})


# no inheritance relationship, explicit coercion necessary
setAs("ELEMENT_VALIDATOR", "ELEMENT_VALIDATION", function(from) {
  new("ELEMENT_VALIDATION", required = from@required, present = TRUE,
    checks = lapply(from@checks, validator2validation))
})


################################################################################


setAs("ELEMENT_VALIDATION", "logical", function(from) {
  if (from@required && !from@present)
    return(FALSE)
  result <- c(present = from@present, vapply(from@checks, as, NA, "logical"))
  if (!result[1L])
    result[-1L] <- NA
  result
})

# no inheritance relationship, explicit coercion necessary
setAs("ELEMENT_VALIDATION", "ELEMENT_VALIDATOR", function(from) {
  new("ELEMENT_VALIDATOR", required = from@required,
    checks = lapply(from@checks, validation2validator))
})


## TODO: => list


################################################################################


setAs("MAP_VALIDATOR", "list", function(from) {
  list(type = "map", required = from@required,
    mapping = sapply(from@checks, as, "list", simplify = FALSE))
})


setAs("list", "MAP_VALIDATOR", function(from) {
  is_map_validator <- function(x) identical(x$type, "map")
  conditionally_create_mv_list <- function(x) {
    found <- match(c("type", "mapping"), names(x), 0L)
    if (found[1L] && !found[2L])
      x$mapping <- structure(list(), names = character())
    if (found[2L] && !found[1L])
      x$type <- "map"
    x
  }
  conditionally_create_mv <- function(x) {
    x <- conditionally_create_mv_list(x)
    as(x, if (is_map_validator(x))
        "MAP_VALIDATOR"
      else
        "ELEMENT_VALIDATOR")
  }
  if (!is_map_validator(from <- conditionally_create_mv_list(from)))
    stop("this list cannot be converted to a MAP_VALIDATOR object")
  if (is.null(required <- from$required))
    required <- FALSE
  new("MAP_VALIDATOR", required = required,
    checks = sapply(from$mapping, conditionally_create_mv, simplify = FALSE))
})

setAs("MAP_VALIDATOR", "MAP_VALIDATION", function(from) {
  new("MAP_VALIDATION", required = from@required, present = TRUE,
    checks = lapply(from@checks, validator2validation))
})


################################################################################


setAs("MAP_VALIDATION", "MAP_VALIDATOR", function(from) {
  new("MAP_VALIDATOR", required = from@required,
    checks = lapply(from@checks, validation2validator))
})


################################################################################

