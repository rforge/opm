#!/usr/local/bin/Rscript --vanilla


################################################################################
#
# docu.R -- Rscript script to non-interactively create documentation for an R
#   package with Roxygen2, to improve this documentation, to update the
#   DESCRIPTION file, to check the package and to install the package. Can also
#   check some aspects of the R coding style and conduct some preprocessing of
#   the code files. Part of the pkgutils package. See the manual for details.
#
# Package directory names can be provided at the command line. If none are
# given, the working directory is checked for subdirectories that contain a
# DESCRIPTION file, and it is then attempted to document those, if any.
#
# (C) 2012-2014 by Markus Goeker (markus [DOT] goeker [AT] dsmz [DOT] de)
#
# This program is distributed under the terms of the Gnu Public License V2.
# For further information, see http://www.gnu.org/licenses/gpl.html
#
################################################################################


local(for (pkg in c("utils", "methods", "pkgutils", "roxygen2"))
  library(package = pkg, quietly = TRUE, warn.conflicts = FALSE,
    character.only = TRUE))


################################################################################


copy_dir <- function(from, to, delete) {
  LL(from, to, delete)
  files <- list.files(path = from, recursive = TRUE, full.names = TRUE)
  files <- c(files, list.files(pattern = "\\.Rbuildignore", full.names = TRUE,
    all.files = TRUE, recursive = TRUE))
  if (nzchar(delete))
    files <- files[!grepl(delete, files, TRUE, TRUE)]
  dirs <- sub(from, to, unique.default(dirname(files)), FALSE, FALSE, TRUE)
  unlink(to, TRUE)
  vapply(dirs[order(nchar(dirs))], dir.create, NA, TRUE, TRUE)
  file.copy(files, sub(from, to, files, FALSE, FALSE, TRUE))
}


vignette_subdirs <- function() {
  c(subdirs <- c("vignettes", "doc"), file.path("inst", subdirs))
}


do_style_check <- function(dirs, opt) {
  check_style <- function(dirs, subdirs, ...) check_R_code(x = dirs,
    what = subdirs, lwd = opt$width, ops = !opt$opsoff, comma = !opt$commaoff,
    indention = opt$blank, roxygen.space = opt$jspaces, modify = opt$modify,
    parens = !opt$parensoff, assign = !opt$assignoff, accept.tabs = opt$tabs,
    three.dots = !opt$dotsok, encoding = opt$encoding, ...)
  subdirs <- c("tests", "scripts")
  subdirs <- c("R", "demo", subdirs, file.path("inst", subdirs))
  y <- check_style(dirs, subdirs, ignore = opt$good, filter = "none")
  y <- c(y, check_style(dirs, subdirs, ignore = opt$good, filter = "roxygen"))
  y <- c(y, check_style(dirs, vignette_subdirs(), filter = "sweave",
    ignore = I(list(pattern = "\\.[RS]?nw$", ignore.case = TRUE))))
  isna <- is.na(y)
  if (any(y & !isna))
    message(paste(sprintf("file '%s' has been modified", names(y)[y & !isna]),
      collapse = "\n"))
  if (any(isna))
    message(paste(sprintf("checking file '%s' resulted in an error",
      names(y)[isna]), collapse = "\n"))
  length(which(isna))
}


do_compact <- function(dirs, opt) {
  pdf.files <- pkg_files(dirs, vignette_subdirs(), FALSE,
    I(list(ignore.case = TRUE, pattern = "\\.pdf$")))
  message("GS command is ", Sys.getenv("R_GSCMD", "<empty>"))
  print(tools::compactPDF(pdf.files, gs_quality = opt$quality))
  0
}


check_S4_methods <- function(pkg) {

  methods_sealed <- function(f, pkg, where = sprintf("package:%s", pkg), ...) {

    fm <- function(f, ...) tryCatch(expr = findMethodSignatures(f = f, ...),
      condition = function(cond) NULL) # skip non-generic functions, if any

    ism <- function(f, s, pkg, where) {
      if (nrow(s) > 1L && sum(bad <- apply(s == "ANY", 1L, all)) == 1L)
        s <- s[!bad, , drop = FALSE] # remove stuff generated by setGeneric()
      for (i in seq_along(sealed <- logical(nrow(s))))
        sealed[[i]] <- isSealedMethod(f, s[i, ], , where)
      data.frame(Function = f, Signature = apply(s, 1L, paste0,
        collapse = "/"), Package = pkg, Sealed = sealed)
    }

    x <- structure(lapply(X = f, FUN = fm, where = where, ...), names = f)
    x <- x[lengths(x, FALSE) > 0L]
    if (!length(x))
      return(NULL)
    do.call(rbind, mapply(FUN = ism, f = names(x), USE.NAMES = FALSE,
      s = x, MoreArgs = list(pkg = pkg, where = where), SIMPLIFY = FALSE))
  }

  test_ambiguity <- function(name) tryCatch(expr = testInheritedMethods(name),
    error = function(e) NULL) # otherwise errors from non-S4 methods

  print_nonsealed <- function(x) {
    if (length(x))
      for (i in seq_len(nrow(x))[!x[, "Sealed"]])
        cat(sprintf("Found 1 %s method with signature %s that is not sealed\n",
          x[i, "Function"], x[i, "Signature"]))
  }

  pkg2 <- sprintf("package:%s", pkg)
  if (!pkg2 %in% search()) {
    library(pkg, character.only = TRUE)
    on.exit(detach(pkg2, unload = TRUE, character.only = TRUE))
  }

  n <- getNamespaceExports(pkg)
  n <- n[!grepl("^\\.__", n, FALSE, TRUE)]
  ambig <- lapply(n, test_ambiguity)
  ambig <- ambig[!vapply(ambig, is.null, NA)]
  ms <- methods_sealed(n, pkg, pkg2)

  cat(sprintf("--- PACKAGE %s ---\n", pkg))
  if (length(ambig)) {
    lapply(ambig, print)
    print_nonsealed(ms)
  }
  cat("\n")

  attr(ambig, "method.sealed") <- ms
  invisible(ambig)
}


run_sweave <- function(files, opt) {
  sum(vapply(files, function(file) {
    tryCatch(expr = {
      Sweave(file = file, encoding = opt$encoding)
      0L
    }, error = function(e) {
      warning(e)
      1L
    })
  }, 0L))
}


do_split <- function(x, sep = ",") {
  x <- unlist(strsplit(x, sep, fixed = TRUE))
  x[nzchar(x)]
}


remove_comments_and_reduce_empty_lines <- function(x) {
  x <- grep("^#", x, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE)
  ne <- nzchar(x)
  x[ne | c(FALSE, ne[-length(ne)])]
}


################################################################################
#
# Spellcheck functions
#


textfile2rds <- function(file, ...) {
  if (!nzchar(file) || grepl("\\.rds$", file, TRUE, TRUE))
    return(file)
  x <- readLines(con = file, ...)
  saveRDS(x[nzchar(x)], file <- tempfile(fileext = ".rds"))
  file
}


show_spellcheck_result <- function(x) {
  if (!nrow(x))
    return(invisible(NULL))
  x[, "File"] <- basename(x[, "File"])
  x <- x[order(x[, "Original"]), c("Original", "File", "Line", "Column")]
  names(x) <- sprintf(".%s.", names(x))
  write.table(x = x, sep = "\t", quote = FALSE, row.names = FALSE)
  invisible(x)
}


news_filter <- function(ifile, encoding) {
  x <- readLines(con = ifile, encoding = encoding, warn = FALSE)
  x <- gsub("(([A-Za-z]+:::?)?[A-Za-z.][\\w.]*|`[^`]+`)\\([^)]*\\)",
    "FUNCTION", x, FALSE, TRUE)
  x <- gsub("'[^']+'", "ARGUMENT", x, FALSE, TRUE)
  x <- gsub("[*][^*]+[*]", "SURNAME", x, FALSE, TRUE)
  x <- gsub("\\b[A-Z]{3,}(_[A-Z]+)*\\b", "ABBREVIATION", x, FALSE, TRUE)
  x <- gsub("\\b(\\d+th|3rd|2nd|1st)\\b", "NUMBERING", x, FALSE, TRUE)
  x
}


demo_filter <- function(ifile, encoding) {
  x <- readLines(con = ifile, encoding = encoding, warn = FALSE)
  x[!grepl("^\\s*#", x, FALSE, TRUE)] <- ""
  x <- gsub("`[^`]+`", "CODE", x, FALSE, TRUE)
  x <- gsub("\\*{2}(?!\\s)[^*]+\\*{2}", "STRONG", x, FALSE, TRUE)
  x <- gsub("\\*(?!\\s)[^*]+\\*", "EMPHASIS", x, FALSE, TRUE)
  x
}


################################################################################


option.parser <- optparse::OptionParser(option_list = list(

  optparse::make_option(c("-a", "--ancient"), action = "store_true",
    default = FALSE,
    help = "Do not update the DESCRIPTION file [default: %default]"),

  optparse::make_option(c("-A", "--assignoff"), action = "store_true",
    default = FALSE,
    help = "Ignore assignments when checking R style [default: %default]"),

  optparse::make_option(c("-b", "--blanks"), type = "integer", default = 2L,
    help = "Number of spaces per indention unit in R code [default: %default]",
    metavar = "NUMBER"),

  optparse::make_option(c("-B", "--buildopts"), type = "character",
    default = "", metavar = "LIST",
    help = "'R CMD build' options, comma-separated list [default: %default]"),

  optparse::make_option(c("-c", "--check"), action = "store_true",
    default = FALSE,
    help = "Run 'R CMD check' after documenting [default: %default]"),

  optparse::make_option(c("-C", "--commaoff"), action = "store_true",
    default = FALSE,
    help = "Ignore comma treatment when checking R style [default: %default]"),

  optparse::make_option(c("-d", "--delete"), type = "character", default = "",
    help = "Subdirectories to delete, colon-separated list [default: %default]",
    metavar = "LIST"),

  optparse::make_option(c("-D", "--dotsok"), action = "store_true",
    default = FALSE,
    help = "Ignore ::: when checking R style [default: %default]"),

  optparse::make_option(c("-e", "--exec"), type = "character", default = "ruby",
    help = "Ruby executable used if -p or -s is chosen [default: %default]",
    metavar = "FILE"),

  optparse::make_option(c("-E", "--encoding"), type = "character", default = "",
    help = "Character encoding assumed in input files [default: %default]",
    metavar = "ENC"),

  optparse::make_option(c("-f", "--format"), type = "character",
    default = "%Y-%m-%d", metavar = "STR",
    help = "Format of the date in the DESCRIPTION file [default: %default]"),

  optparse::make_option(c("-F", "--folder"), action = "store_true",
    default = FALSE, help = paste("When using -y, check and install not the",
      "archive but the folder [default: %default]")),

  # A bug in Rscript causes '-g' to generate strange warning messages.
  # See https://stat.ethz.ch/pipermail/r-devel/2008-January/047944.html
  #
  # g

  optparse::make_option(c("-G", "--good"), type = "character", default = "",
    help = paste("R code files to not check, comma-separated list",
    "[default: %default]"), metavar = "LIST"),

  # h is reserved for help!

  optparse::make_option(c("-H", "--inheritance"), action = "store_true",
    default = FALSE,
    help = "Check ambiguity of S4 method selection [default: %default]"),

  optparse::make_option(c("-i", "--install"), action = "store_true",
    default = FALSE,
    help = "Also run 'R CMD INSTALL' after documenting [default: %default]"),

  optparse::make_option(c("-I", "--installopts"), type = "character",
    default = "", metavar = "LIST",
    help = "'R CMD INSTALL' options, comma-separated list [default: %default]"),

  optparse::make_option(c("-j", "--jspaces"), type = "integer", default = 1L,
    help = paste("Number of spaces starting Roxygen-style comments",
    "[default: %default]"), metavar = "NUMBER"),

  optparse::make_option(c("-J", "--junk"), type = "character", default = "",
    help = "Pattern of files to not copy with directory [default: %default]",
    metavar = "PATTERN"),

  optparse::make_option(c("-k", "--keep"), action = "store_true",
    default = FALSE,
    help = "Keep the version number in DESCRIPTION files [default: %default]"),

  # K

  optparse::make_option(c("-l", "--logfile"), type = "character",
    default = "docu_%s.log", metavar = "FILE",
    help = "Logfile to use for problem messages [default: %default]"),

  optparse::make_option(c("-L", "--lines-reduce"), action = "store_true",
    default = FALSE,
    help = "Reduce number of lines in R code [default: %default]"),

  optparse::make_option(c("-m", "--modify"), action = "store_true",
    default = FALSE, help = paste("Potentially modify R sources when",
      "style checking [default: %default]")),

  optparse::make_option(c("-M", "--mark-duplicates"), action = "store_true",
    help = "Mark duplicate words in Rd text [default: %default]",
    default = FALSE),

  optparse::make_option(c("-n", "--nosudo"), action = "store_true",
    default = FALSE,
    help = "In conjunction with -i, do not use sudo [default: %default]"),

  optparse::make_option(c("-N", "--no-internal"), action = "store_true",
    default = FALSE,
    help = "Remove Rd files with 'internal' as keyword [default: %default]"),

  optparse::make_option(c("-o", "--options"), type = "character",
    default = "timings", metavar = "LIST",
    help = "'R CMD check' options, comma-separated list [default: %default]"),

  optparse::make_option(c("-O", "--opsoff"), action = "store_true",
    default = FALSE,
    help = "Ignore operators when checking R style [default: %default]"),

  optparse::make_option(c("-p", "--preprocess"), action = "store_true",
    default = FALSE,
    help = "Preprocess R files using code swapping [default: %default]"),

  optparse::make_option(c("-P", "--parensoff"), action = "store_true",
    default = FALSE,
    help = "Ignore parentheses when checking R style [default: %default]"),

  optparse::make_option(c("-q", "--quick"), action = "store_true",
    default = FALSE,
    help = "Do not remove duplicate 'seealso' links [default: %default]"),

  optparse::make_option(c("-Q", "--quality"), type = "character", default = "",
    help = "PDF quality for running in compression mode [default: %default]",
    metavar = "STR"),

  optparse::make_option(c("-r", "--remove"), action = "store_true",
    default = FALSE,
    help = "First remove output directories if distinct [default: %default]"),

  optparse::make_option(c("-R", "--Rcheck"), action = "store_true",
    default = FALSE,
    help = "Check only format of R code, ignore packages [default: %default]"),

  optparse::make_option(c("-s", "--S4methods"), action = "store_true",
    default = FALSE,
    help = "Repair S4 method descriptions [default: %default]"),

  optparse::make_option(c("-S", "--Sweave"), action = "store_true",
    default = FALSE,
    help = "Run Sweave on input files, ignore packages [default: %default]"),

  optparse::make_option(c("-t", "--target"), type = "character",
    default = file.path(Sys.getenv("HOME"), "bin"), metavar = "DIR",
    help = paste("For -i, script file target directory; ignored if",
      "empty [default: %default]")),

  optparse::make_option(c("-T", "--tabs"), action = "store_true",
    default = FALSE,
    help = "Accept tabs when checking R style [default: %default]"),

  optparse::make_option(c("-u", "--unsafe"), action = "store_true",
    default = FALSE,
    help = "In conjunction with -i, omit checking [default: %default]"),

  optparse::make_option(c("-U", "--untidy"), action = "store_true",
    default = FALSE,
    help = "Omit R style checking altogether [default: %default]"),

  optparse::make_option(c("-v", "--verbatim"), action = "store_true",
    default = FALSE, help = paste("No special processing of package names",
      "ending in '*_in' [default: %default]")),

  # V

  optparse::make_option(c("-w", "--width"), type = "integer", default = 80L,
    help = "Maximum allowed line width in R code [default: %default]",
    metavar = "NUMBER"),

  optparse::make_option(c("-W", "--whitelist"), type = "character",
    default = "", metavar = "LIST",
    help = paste("Spell check with this white list [default: %default]")),

  optparse::make_option(c("-x", "--exclude"), type = "character", default = "",
    help = paste("Files to ignore when using -t, comma-separated list",
      "[default: %default]"), metavar = "LIST"),

  # X

  optparse::make_option(c("-y", "--yes"), action = "store_true",
    default = FALSE, help = "Yes, also build the package [default: %default]"),

  # Y

  optparse::make_option(c("-z", "--zapoff"), action = "store_true",
    default = FALSE,
    help = "Do not zap object files in 'src', if any [default: %default]")

  # Z

), usage = "%prog [options] [directories/files]")


opt <- optparse::parse_args(option.parser, positional_arguments = TRUE)
package.dirs <- opt$args
opt <- opt$options


if (opt$help || (opt$Rcheck && !length(package.dirs))) {
  optparse::print_help(option.parser)
  quit(status = 1L)
}


opt$options <- do_split(opt$options)
opt$installopts <- do_split(opt$installopts)
opt$buildopts <- do_split(opt$buildopts)
opt$delete <- do_split(opt$delete, ":")
opt$good <- basename(do_split(opt$good))
opt$exclude <- do_split(opt$exclude)
opt$whitelist <- textfile2rds(opt$whitelist)


################################################################################


if (opt$inheritance) {
  package.dirs <- basename(package.dirs)
  if (!opt$verbatim)
    package.dirs <- sub("_in$", "", package.dirs, FALSE, TRUE)
  invisible(lapply(package.dirs, check_S4_methods))
  quit(status = 0L)
}


################################################################################


if (opt$Sweave) { # Sweave running mode
  quit(status = run_sweave(package.dirs, opt))
}


################################################################################


if (opt$Rcheck) { # R style check only
  quit(status = do_style_check(package.dirs, opt))
}


################################################################################


if (length(package.dirs)) {
  if (length(bad <- package.dirs[!is_pkg_dir(package.dirs)]))
    stop("not a package directory: ", bad[1L])
  package.dirs <- dirname(sprintf("%s/.", package.dirs))
} else {
  package.dirs <- list.files()
  package.dirs <- package.dirs[is_pkg_dir(package.dirs)]
  if (!length(package.dirs)) {
    warning("no package directories provided, and none found in ", getwd(),
      "\nuse command-line switches '--help' or '-h' for help")
    quit(status = 1L)
  }
}


if (opt$verbatim) {
  out.dirs <- package.dirs
} else {
  out.dirs <- sub("_in$", "", package.dirs, FALSE, TRUE)
  ok <- package.dirs != out.dirs
  ok[!ok][!package.dirs[!ok] %in% out.dirs[ok]] <- TRUE
  package.dirs <- package.dirs[ok]
  out.dirs <- out.dirs[ok]
  rm(ok)
  if (opt$remove) {
    message("Removing distinct output directories (if any)...")
    unlink(out.dirs[out.dirs != package.dirs], recursive = TRUE)
  }
}

msgs <- sprintf(" package directory '%s'...", out.dirs)
msgs.1 <- sprintf(" input directory '%s'...", package.dirs)

logfiles <- if (nzchar(opt$logfile)) {
  file.path(dirname(out.dirs), sprintf(opt$logfile, basename(out.dirs)))
} else {
  rep("", length(out.dirs))
}


errs <- 0L


################################################################################


if (nzchar(opt$target) && !file_test("-d", opt$target)) {
  warning(sprintf("'%s' is not a directory", opt$target))
  opt$target <- ""
  errs <- errs + 1L
}


for (i in seq_along(package.dirs)) {

  out.dir <- out.dirs[i]
  in.dir <- package.dirs[i]
  msg <- msgs[i]

  if (!opt$ancient) {
    # This must be applied to the input directory if it is distinct from the
    # output directory.
    message("Updating DESCRIPTION of", msgs.1[i])
    tmp <- pack_desc(in.dir, "update", version = !opt$keep,
      date.format = opt$format)
    message(paste(formatDL(tmp[1L, ], style = "list"), collapse = "\n"))
  }

  if (!identical(out.dir, in.dir)) {
    # Copying the files is preferred to calling roxygenize() with two
    # directory arguments because due to a Roxygen2 bug this would result in
    # duplicated documentation for certain S4 methods.
    message(sprintf("Copying '%s' to '%s'...", in.dir, out.dir))
    copy_dir(in.dir, out.dir, opt$junk)
    if (length(opt$delete)) {
      message("Deleting specified subdirectories (if present) of", msg)
      unlink(file.path(out.dir, opt$delete), recursive = TRUE)
    }
  }

  message(sprintf("Logfile is now '%s'", logfile(logfiles[i])))

  if (!opt$untidy) {
    message("Checking R code of", msg)
    errs <- errs + do_style_check(out.dir, opt)
    message("Checking Sweave code-chunk headers of", msg)
    check_Sweave_start(out.dir)
  }

  message("Creating documentation for", msg)
  if (out.dir == "pkgutils") {
    message(sprintf("(temporarily unloading '%s' package)", out.dir))
    detach(name = sprintf("package:%s", out.dir), unload = TRUE,
      character.only = TRUE) # necessary to allow sealed S4 methods
    roxygenize(out.dir)
    library(package = out.dir, character.only = TRUE)
  } else {
    roxygenize(out.dir)
  }

  message("Repairing documentation for", msg)
  skip <- repair_docu(out.dir, remove.dups = !opt$quick,
    drop.internal = opt$`no-internal`, text.dups = opt$`mark-duplicates`)
  if (is.logical(skip) && any(skip))
    skip <- paste0("--skip=", paste0(names(skip)[skip], collapse = ","))
  else
    skip <- ""

  if (opt$S4methods) {
    message("Repairing S4 method documentation for", msg)
    errs <- errs + repair_S4_docu(out.dir, ruby = opt$exec, sargs = skip)
  }

  if (suppressWarnings(file.remove(file.path(out.dir, "inst"))))
    message("Deleting empty 'inst' subdirectory of", msg)

  if (opt$preprocess) {
    message("Preprocessing R code of", msg)
    errs <- errs + swap_code(out.dir, ruby = opt$exec)
  }

  if (opt$`lines-reduce` && !identical(in.dir, out.dir)) {
    message("Removing comments and reducing empty lines of", msg)
    map_files(list.files(file.path(out.dir, "R"), full.names = TRUE),
      remove_comments_and_reduce_empty_lines)
  }

  if (!opt$zapoff) {
    message("Deleting object files (if any) of", msg)
    errs <- errs + !all(delete_o_files(out.dir))
  }

  if (nzchar(opt$quality)) {
    message("Compacting PDF files (if any) of", msg)
    do_compact(out.dir, opt)
  }

  pkg.file <- out.dir

  if (opt$yes) {
    message("Building", msg)
    build.err <- run_R_CMD(out.dir, "build", opt$buildopts)
    errs <- errs + build.err
    if (!opt$folder) {
      pkg.file <- sprintf("%s_%s.tar.gz", basename(out.dir),
        pack_desc(out.dir)[[1L]]$Version)
      msg <- sprintf(" archive file '%s'...", pkg.file)
    }
  }

  if (opt$check || ((opt$install || opt$yes) && !opt$unsafe)) {
    message("Checking", msg)
    errs <- errs + (check.err <- run_R_CMD(pkg.file, "check", opt$options))
  }

  if (nzchar(opt$whitelist)) {
    message("Checking spelling in Rd files of", msg)
    show_spellcheck_result(aspell_package_Rd_files(out.dir,
      control = "-d en_GB", dictionaries = opt$whitelist,
      drop = c("\\author", "\\references", "\\seealso", "\\code",
        "\\acronym", "\\pkg", "\\kbd", "\\command", "\\file")))
    message("Checking spelling in DESCRIPTION file of", msg)
    show_spellcheck_result(pack_desc(out.dir, "spell",
      dictionaries = opt$whitelist, control = "-d en_GB"))
    message("Checking spelling in NEWS/ChangeLog files (if any) of", msg)
    ff <- file.path(out.dir, c("NEWS", "ChangeLog"))
    for (f in ff[file.exists(ff)])
      show_spellcheck_result(aspell(f, dictionaries = opt$whitelist,
        control = "-d en_GB", filter = news_filter))
    message("Checking spelling in demo R files (if any) of", msg)
    ff <- list.files(file.path(out.dir, "demo"), full.names = TRUE)
    for (f in grep("\\.R$", ff, TRUE, TRUE, TRUE))
      show_spellcheck_result(aspell(f, dictionaries = opt$whitelist,
        control = "-d en_GB", filter = demo_filter))
  }

  if (opt$install && (opt$unsafe || !check.err)) {
    message("Installing", msg)
    install.err <- run_R_CMD(out.dir, "INSTALL", opt$installopts,
      sudo = !opt$nosudo)
    errs <- errs + install.err
    if (!install.err && nzchar(opt$target)) {
      message("Copying script files (if any)...")
      errs <- errs + !all(copy_pkg_files(x = basename(out.dir),
        to = opt$target, ignore = opt$exclude))
    }
  }

}


quit(status = errs)


################################################################################


