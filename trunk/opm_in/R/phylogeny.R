

################################################################################
################################################################################
#
# Phylogeny- related methods
#


#' \acronym{HTML} formatting and output label generation
#'
#' These are helper functions for \code{\link{phylo_data}} allowing for either
#' the easy fine-tuning of the generated \acronym{HTML} output or for the
#' conversions of strings to safe phylogenetic taxon labels.
#'
#' @param character.states Character vector used for mapping integers to the
#'   elements in the corresponding position. It is also used in conjunction
#'   with its names to create the table legend. The default value is useful
#'   for data of mode \sQuote{logical}, mapping \code{FALSE}, \code{NA} and
#'   \code{TRUE}, in this order. Data of this kind are by default internally
#'   converted to an according integer vector.
#' @param multiple.sep Character scalar used for joining multiple-state
#'   characters together.
#' @param organisms.start Character scalar prepended to the organism part of the
#'   table legend. Ignored if empty.
#' @param states.start Character scalar prepended to the character-states part
#'   of the table legend. Ignored if empty.
#' @param legend.dot Logical scalar indicating whether or not a dot shall be
#'   appended to the table-legend entries.
#' @param legend.sep.1 Character scalar used for the first pass of joining
#'   the table-legend entries together.
#' @param legend.sep.2 Character scalar used for the second pass of joining
#'   the table-legend entries together.
#' @param table.summary Character scalar inserted as \sQuote{summary} attribute
#'   of the resulting \code{HTML} table.
#' @param no.html Logical scalar indicating whether substrate names should be
#'   cleaned from characters that might interfere with \code{HTML} code. Setting
#'   this to \code{FALSE} might yield invalid \code{HTML}.
#' @param greek.letters Logical scalar indicating whether or not letters between
#'   \sQuote{a} and \sQuote{e} within substrate names should be converted to the
#'   corresponding Greek letters. This is done after the cleaning step, if any.
#' @param css.file Character vector indicating the name of one to several
#'   \acronym{CSS} files to link or embed. Empty strings and empty vectors are
#'   ignored. If \code{embed.css} is \code{FALSE} it is no error if the file
#'   does not exist, but the page will then probably not be displayed as
#'   intended.
#'
#'   Under Windows it is recommended to convert a file name \code{f} using
#'   \code{normalizePath(f, winslash = "/")} before linking it.
#' @param embed.css Logical scalar indicating whether or not \acronym{CSS} files
#'   shall be embedded, not linked.
#' @param ... Optional other arguments available for inserting user-defined
#'   \acronym{HTML} content. Currently the following ones (in their order of
#'   insertion) are not ignored, and can even be provided several times:
#'   \describe{
#'     \item{meta}{Used as (additional) \sQuote{meta} entries within the
#'       \acronym{HTML} head.}
#'     \item{headline}{Override the use of the \code{title} argument as headline
#'       (placed above the table legend). An empty argument would turn it off.}
#'     \item{prepend}{List or character vector to be inserted before the table
#'       legend. Lists are converted recursively. List names will be converted
#'       to \sQuote{title} and \sQuote{class} attributes (if missing, names are
#'       inferred from the nesting level; see \code{\link{opm_opt}}, entry
#'       \code{html.class}). Names of other vectors, if any, are converted to
#'       \sQuote{title} and \sQuote{span} attributes. Character vectors are
#'       converted using \code{\link{safe_labels}} unless they inherit from
#'       \code{AsIs} (see \code{I} from the \pkg{base} package).}
#'     \item{insert}{As above, but inserted between the legend and the table.}
#'     \item{append}{As above, but inserted after the table.}
#'   }
#'
#' @param x Character vector or convertible to such.
#' @param format Character scalar. See \code{\link{phylo_data}}.
#' @param enclose Logical scalar. See \code{\link{phylo_data}} and the
#'   description of \code{comment}.
#' @param pad Logical scalar. Bring labels to the same number of characters by
#'   appending spaces? Has no effect for \acronym{PHYLIP} and \acronym{HTML}
#'   output format.
#' @param comment Logical scalar. If \code{TRUE}, comments as used in the
#'   respective format will be produced. \acronym{PHYLIP} and \acronym{EPF} do
#'   not accept comments and will yield an error. If \code{enclose} is
#'   \code{TRUE}, the comment-enclosing characters are appended and prepended to
#'   the vector, otherwise to each string separately.
#'
#' @return List of \acronym{HTML} arguments or character vector with modified
#'   labels.
#' @details These functions are not normally called directly by an \pkg{opm}
#'   user but by \code{\link{phylo_data}}; see there for their usual
#'   application. The \code{\link{phylo_data}} methods for \code{OPMD_Listing}
#'   and \code{OPMS_Listing} objects do not support all \acronym{HTML}
#'   formatting options.
#'
#'   Label cleaning invokes either the replacement of disallowed characters or
#'   the enclosing of all labels in single quotes and the doubling of
#'   already existing single quotes, if any.
#'
#' @keywords character cluster IO
#' @seealso base::normalizePath base::I base::gsub
#' @export
#' @family phylogeny-functions
#' @examples
#' # Some animals you might know
#' x <- c("Elephas maximus", "Loxodonta africana", "Giraffa camelopardalis")
#'
#' (y <- safe_labels(x, "phylip"))
#' stopifnot(nchar(y) == 10L) # truncation
#'
#' (y <- safe_labels(x, "epf"))
#' stopifnot(nchar(y) == nchar(x)) # changes in length unnecessary
#' (y <- safe_labels(x, "epf", pad = TRUE))
#' stopifnot(nchar(y) == 22) # padded to uniform length
#'
#' (y <- safe_labels(x, "nexus", enclose = TRUE))
#' stopifnot(grepl("^'.*'$", y)) # all strings enclosed in sinqle quotes
#'
html_args <- function(
    character.states = c(`negative reaction` = "-",
    `weak reaction` = "w", `positive reaction` = "+"),
    multiple.sep = "/", organisms.start = "Organisms: ",
    states.start = "Symbols: ", legend.dot = TRUE,
    legend.sep.1 = ", ", legend.sep.2 = "; ",
    table.summary = "character matrix", no.html = TRUE,
    greek.letters = TRUE, css.file = opm_opt("css.file"),
    embed.css = FALSE, ...) {
  args <- as.list(match.call())[-1L]
  defaults <- formals()[setdiff(names(formals()), c(names(args), "..."))]
  lapply(c(defaults, args), eval)
}

#' @rdname html_args
#' @export
#'
safe_labels <- function(x, format, enclose = TRUE, pad = FALSE,
    comment = FALSE) {
  do_pad <- function(x, pad) {
    if (pad)
      sprintf(sprintf("%%-%is", max(nchar(x))), x)
    else
      x
  }
  nexus_quote <- function(x) {
    sprintf("'%s'", gsub("'", "''", x, FALSE, FALSE, TRUE))
  }
  clean_html <- function(x) {
    x <- gsub("&(?!([A-Za-z]+|#\\d+);)", "&amp;", x, FALSE, TRUE)
    x <- gsub("<", "&lt;", x, FALSE, FALSE, TRUE)
    x <- gsub(">", "&gt;", x, FALSE, FALSE, TRUE)
    gsub("\"", "&quot;", x, FALSE, FALSE, TRUE)
  }
  clean_from <- function(x, pat) {
    pat <- sprintf("[%s]+", pat)
    x <- sub(sprintf("^%s", pat), "", x, FALSE, TRUE)
    x <- sub(sprintf("%s$", pat), "", x, FALSE, TRUE)
    gsub(pat, "_", x, FALSE, TRUE)
  }
  surround <- function(x, start, end, enclose) {
    if (enclose)
      c(start, x, end)
    else
      sprintf("%s%s%s", start, x, end)
  }
  LL(enclose, pad, comment)
  format <- match.arg(format, PHYLO_FORMATS)
  if (comment) {
    case(format,
      html = surround( # the replacement used is the one favoured by HTML Tidy
        gsub("--", "==", x, FALSE, FALSE, TRUE), "<!-- ", " -->", enclose),
      hennig = surround(chartr("'", '"', x), "'", "'", enclose),
      nexus = surround(chartr("[]", "{}", x), "[", "]", enclose),
      epf =,
      phylip = stop("comments are not defined for format ", format)
    )
  } else {
    not.newick <- "\\s,:;()" # spaces and Newick-format special characters
    not.nexus <- "\\s()\\[\\]{}/\\,;:=*'\"`+<>-" # see PAUP* manual
    # see http://tnt.insectmuseum.org/index.php/Basic_format (16/04/2012)
    not.hennig <- "\\s;/+-"
    case(format,
      html = clean_html(x),
      phylip = sprintf("%-10s", substr(clean_from(x, not.newick), 1L, 10L)),
      hennig = do_pad(clean_from(x, not.hennig), pad),
      epf = do_pad(clean_from(x, not.newick), pad),
      nexus = do_pad(if (enclose)
        nexus_quote(x)
      else
        clean_from(x, not.nexus), pad)
    )
  }
}


################################################################################


#' Export phylogenetic data
#'
#' Create entire character matrix (include header and footer) in a file format
#' suitable for exporting phylogenetic data. Return it or write it to a file.
#' This function can also produce \acronym{HTML} tables and text paragraphs
#' suitable for displaying \acronym{PM} data in taxonomic journals such as
#' \acronym{IJSEM}.
#'
#' @param object Data frame, numeric matrix or \code{\link{OPMS}} or
#'   \code{\link{MOPMX}} object (with aggregated values). Currently only
#'   \sQuote{integer}, \sQuote{logical}, \sQuote{double} and \sQuote{character}
#'   matrix content is supported. The data-frame and \code{\link{OPMS}} methods
#'   first call \code{\link{extract}} and then the matrix method. The methods
#'   for \code{OPMD_Listing} and \code{OPMS_Listing} objects can be applied to
#'   the results of \code{\link{listing}}.
#' @param format Character scalar determining the output format, either
#'   \kbd{epf} (Extended \acronym{PHYLIP} Format), \kbd{nexus}, \kbd{phylip},
#'   \kbd{hennig} or \kbd{html}.
#'
#'   If \acronym{NEXUS} or \sQuote{Hennig} format is chosen, a non-empty
#'   \code{comment} attribute will be output together with the data (and
#'   appropriately escaped). In case of \acronym{HTML} format, a non-empty
#'   \code{comment} yields the title of the HTML document.
#'
#'   \acronym{EPF} or \sQuote{extended \acronym{PHYLIP}} is sometimes called
#'   \sQuote{relaxed \acronym{PHYLIP}}. The main difference between
#'   \acronym{EPF} and \acronym{PHYLIP} is that the former can use labels with
#'   more than ten characters, but its labels must not contain whitespace.
#'   (These adaptations are done automatically with \code{\link{safe_labels}}.)
#' @param outfile Character scalar. If a non-empty character scalar, resulting
#'   lines are directly written to this file. Otherwise, they are returned.
#' @param enclose Logical scalar. Shall labels be enclosed in single quotes?
#'   Ignored unless \code{format} is \sQuote{nexus}.
#' @param indent Integer scalar. Indentation of commands in NEXUS format.
#'   Ignored unless \code{format} is \sQuote{nexus} (and a matter of taste
#'   anyway).
#' @param paup.block Logical scalar. Append a \acronym{PAUP*} block with
#'   selected (recommended) default values? Has no effect unless \sQuote{nexus}
#'   is selected as \sQuote{format}.
#' @param delete Character scalar with one of the following values:
#'   \describe{
#'   \item{uninf}{Columns are removed which are either constant (in the strict
#'   sense) or are columns in which some fields contain polymorphisms, and no
#'   pairs of fields share no character states.}
#'   \item{ambig}{Columns with ambiguities (multiple states in at least one
#'   single field) are removed.}
#'   \item{constant}{Columns which are constant in the strict sense are
#'   removed.}
#'   }
#'   \code{delete} is currently ignored for formats other than \acronym{HTML},
#'   and note that columns become rows in the final \acronym{HTML} output.
#'
#' @param join Logical scalar, vector or factor. Unless \code{FALSE}, rows of
#'   \code{object} are joined together, either according to the row names (if
#'   \code{join} is \code{TRUE}), or directly according to \code{join}. This can
#'   be used to deal with measurements repetitions for the same organism or
#'   treatment.
#' @param cutoff Numeric scalar. If joining results in multiple-state
#'   characters, they can be filtered by removing all entries with a relative
#'   frequency less than \sQuote{cutoff}. Makes not much sense for non-integer
#'   numeric data.
#' @param digits Numeric scalar. Used for rounding, and thus ignored unless
#'   \code{object} is of mode \sQuote{numeric}.
#' @param comments Character vector. Comments to be added to the output (as
#'   title if \acronym{HTML} is chosen). Ignored if the output format does not
#'   allow for comments. If empty, a default comment is chosen.
#' @param html.args List of arguments used to modify the generated
#'   \acronym{HTML}. See \code{\link{html_args}} for the supported list
#'   elements and their meaning.
#' @param prefer.char Logical scalar indicating whether or not to use \code{NA}
#'   as intermediary character state. Has only an effect for \sQuote{logical}
#'   and \sQuote{integer} characters. A warning is issued if integers are not
#'   within the necessary range, i.e. either \code{0} or \code{1}.
#' @param run.tidy Logical scalar. Filter the resulting \acronym{HTML} through
#'   the Tidy program? Ignored unless \code{format} is \kbd{html}. Otherwise,
#'   if \code{TRUE}, it is an error if the Tidy executable is not found.
#'
#' @param as.labels Vector of data-frame indexes or \code{\link{OPMS}} metadata
#'   entries. See \code{\link{extract}}.
#' @param sep Character scalar. See \code{\link{extract}}.
#'
#' @param subset Character scalar. For the \code{\link{OPMS}} method, passed to
#'   the \code{\link{OPMS}} method of \code{\link{extract}}. For the data-frame
#'   method, a selection of column classes to extract.
#' @param extract.args Optional list of arguments passed to that method.
#' @param discrete.args Optional list of arguments passed from the
#'   \code{\link{OPMS}} method to \code{\link{discrete}}. If set to \code{NULL},
#'   discretisation is turned off. Ignored if stored discretised values are
#'   chosen by setting \code{subset} to \code{\link{param_names}("disc.name")}.
#'
#' @param ... Optional arguments passed between the methods (i.e., from the
#'   other methods to the matrix method) or to \code{hwrite} from the
#'   \pkg{hwriter} package. Note that \sQuote{table.summary} is set via
#'   \code{html.args} and that \sQuote{page}, \sQuote{x} and \sQuote{div}
#'   cannot be used.
#'
#' @export
#' @return Character vector, each element representing a line in a potential
#'   output file, returned invisibly if \code{outfile} is given.
#' @family phylogeny-functions
#' @seealso base::comment base::write hwriter::hwrite
#' @details Exporting \acronym{PM} data in such formats allows one to either
#'   infer trees from the data under the maximum-likelihood and/or the
#'   maximum-parsimony criterion, or to reconstruct the evolution of
#'   \acronym{PM} characters on given phylogenetic trees, or to nicely display
#'   the data in \acronym{HTML} format.
#'
#'   For exporting NEXUS format, the matrix should normally be converted
#'   beforehand by applying \code{\link{discrete}}. Exporting \acronym{HTML} is
#'   optimised for data discretised with \code{gap} set to \code{TRUE}. For
#'   other data, the \code{character.states} argument should be modified, see
#'   \code{\link{html_args}}. The \kbd{hennig} (Hennig86) format is the one
#'   used by \acronym{TNT}; it allows continuous characters to be analysed as
#'   such. Regarding the meaning of \sQuote{character} as used here, see the
#'   \sQuote{Details} section of \code{\link{discrete}}.
#'
#'   The generated \acronym{HTML} is guaranteed to produce neither errors nor
#'   warnings if checked using the Tidy program. It deliberately contains no
#'   formatting instructions but a rich annotation with \sQuote{class}
#'   attributes which allows for \acronym{CSS}-based formatting. This annotation
#'   includes the naming of all sections and all kinds of textual content.
#'   Whether the characters show differences between at least one organism and
#'   the others is also indicated. For the \acronym{CSS} files that come with
#'   the package, see the examples below and \code{\link{opm_files}}.
#' @keywords character cluster IO
#'
#' @references Berger, S. A., Stamatakis, A. 2010 Accuracy of morphology-based
#'   phylogenetic fossil placement under maximum likelihood. \emph{8th ACS/IEEE
#'   International Conference on Computer Systems and Applications (AICCSA-10).}
#'   Hammamet, Tunisia [analysis of phenotypic data with RAxML].
#' @references Felsenstein, J. 2005 PHYLIP (Phylogeny Inference Package) version
#'   3.6. Distributed by the author. Seattle: University of Washington,
#'   Department of Genome Sciences [the PHYLIP program].
#' @references Goloboff, P.A., Farris, J.S., Nixon, K.C. 2008 TNT, a free
#'   program for phylogenetic analysis. \emph{Cladistics} \strong{24}, 774--786
#'   [the TNT program].
#' @references Goloboff, P.A., Mattoni, C., Quinteros, S. 2005 Continuous
#'   characters analysed as such. \emph{Cladistics} \strong{22}, 589--601.
#' @references Maddison, D. R., Swofford, D. L., Maddison, W. P. 1997 Nexus: An
#'   extensible file format for systematic information. \emph{Syst Biol}
#'   \strong{46}, 590--621 [the NEXUS format].
#' @references Stamatakis, A. 2006 RAxML-VI-HPC: Maximum likelihood-based
#'   phylogenetic analyses with thousands of taxa and mixed models
#'   \emph{Bioinformatics} \strong{22}, 2688--2690. [the RAxML program].
#' @references Swofford, D. L. 2002 \emph{PAUP*: Phylogenetic Analysis Using
#'   Parsimony (*and Other Methods), Version 4.0 b10}. Sunderland, Mass.:
#'   Sinauer Associates [the PAUP* program].
#' @references \url{http://ijs.sgmjournals.org/} [IJSEM journal]
#' @references \url{http://tidy.sourceforge.net/} [HTML Tidy]
#'
#' @examples
#'
#' # simple helper functions
#' echo <- function(x) write(substr(x, 1, 250), file = "")
#' is_html <- function(x) is.character(x) &&
#'   c("<html>", "<head>", "<body>", "</html>", "</head>", "</body>") %in% x
#' longer <- function(x, y) any(nchar(x) > nchar(y)) &&
#'   !any(nchar(x) < nchar(y))
#'
#' ## examples with a dummy data set
#' x <- matrix(c(0:9, letters[1:22]), nrow = 2)
#' colnames(x) <- LETTERS[1:16]
#' rownames(x) <- c("Ahoernchen", "Behoernchen") # Chip and Dale in German
#'
#' # EPF is a comparatively restricted format
#' echo(y.epf <- phylo_data(x, format = "epf"))
#' stopifnot(is.character(y.epf), length(y.epf) == 3)
#' stopifnot(identical(y.epf, phylo_data(as.data.frame(x), subset = "factor",
#'   format = "epf")))
#'
#' # PHYLIP is even more restricted (shorter labels!)
#' echo(y.phylip <- phylo_data(x, format = "phylip"))
#' stopifnot((y.epf == y.phylip) == c(TRUE, FALSE, FALSE))
#'
#' # NEXUS allows for more content; note the comment and the character labels
#' echo(y.nexus <- phylo_data(x, format = "nexus"))
#' nexus.len.1 <- length(y.nexus)
#' stopifnot(is.character(y.nexus), nexus.len.1 > 10)
#'
#' # adding a PAUP* block with (hopefully useful) default settings
#' echo(y.nexus <- phylo_data(x, format = "nexus", paup.block = TRUE))
#' stopifnot(is.character(y.nexus), length(y.nexus) > nexus.len.1)
#'
#' # adding our own comment
#' comment(x) <- c("This is", "a test") # yields two lines
#' echo(y.nexus <- phylo_data(x, format = "nexus"))
#' stopifnot(identical(length(y.nexus), nexus.len.1 + 1L))
#'
#' # Hennig86/TNT also includes the comment
#' echo(y.hennig <- phylo_data(x, format = "hennig"))
#' hennig.len.1 <- length(y.hennig)
#' stopifnot(is.character(y.hennig), hennig.len.1 > 10)
#'
#' # without an explicit comment, the default one will be used
#' comment(x) <- NULL
#' echo(y.hennig <- phylo_data(x, format = "hennig"))
#' stopifnot(identical(length(y.hennig), hennig.len.1 - 1L))
#'
#' ## examples with real data and HTML
#'
#' # setting the CSS file that comes with opm as default
#' opm_opt(css.file = opm_files("css")[[1]])
#'
#' # see discrete() for the conversion and note the OPMS example below: one
#' # could also get the results directly from OPMS objects
#' x <- extract(vaas_4[, , 1:10], as.labels = list("Species", "Strain"),
#'   in.parens = FALSE)
#' x <- discrete(x, range = TRUE, gap = TRUE)
#' echo(y <- phylo_data(x, format = "html",
#'   html.args = html_args(organisms.start = "Strains: ")))
#' # this yields HTML with the usual tags, a table legend, and the table itself
#' # in a single line; the default 'organisms.start' could also be used
#' stopifnot(is_html(y))
#'
#' # now with joining of the results per species (and changing the organism
#' # description accordingly)
#' x <- extract(vaas_4[, , 1:10], as.labels = list("Species"),
#'   in.parens = FALSE)
#' x <- discrete(x, range = TRUE, gap = TRUE)
#' echo(y <- phylo_data(x, format = "html", join = TRUE,
#'   html.args = html_args(organisms.start = "Species: ")))
#' stopifnot(is_html(y))
#' # Here and in the following examples note the highlighting of the variable
#' # (uninformative or informative) characters. The uninformative ones are those
#' # that are not constant but show overlap regarding the sets of character
#' # states between all organisms. The informative ones are those that are fully
#' # distinct between all organisms.
#'
#' # 'OPMS' method, yielding the same results than above but directly
#' echo(yy <- phylo_data(vaas_4[, , 1:10], as.labels = "Species",
#'   format = "html", join = TRUE, extract.args = list(in.parens = FALSE),
#'   html.args = html_args(organisms.start = "Species: ")))
#' # the timestamps might differ, but otherwise the result is as above
#' stopifnot(length(y) == length(yy) && length(which(y != yy)) < 2)
#'
#' # appending user-defined sections
#' echo(yy <- phylo_data(vaas_4[, , 1:10], as.labels = "Species",
#'   format = "html", join = TRUE, extract.args = list(in.parens = FALSE),
#'   html.args = html_args(organisms.start = "Species: ",
#'   append = list(section.1 = "additional text", section.2 = "more text"))))
#' stopifnot(length(y) < length(yy), length(which(!y %in% yy)) < 2)
#' # note the position -- there are also 'prepend' and 'insert' arguments
#'
#' # effect of deletion
#' echo(y <- phylo_data(x, "html", delete = "none", join = FALSE))
#' echo(y.noambig <- phylo_data(x, "html", delete = "ambig", join = FALSE))
#' stopifnot(length(which(y != y.noambig)) < 2) # timestamps might differ
#' # ambiguities are created only by joining
#' echo(y <- phylo_data(x, "html", delete = "none", join = TRUE))
#' echo(y.noambig <- phylo_data(x, "html", delete = "ambig", join = TRUE))
#' stopifnot(longer(y, y.noambig))
#' echo(y.nouninf <- phylo_data(x, "html", delete = "uninf", join = TRUE))
#' stopifnot(longer(y, y.nouninf))
#' echo(y.noconst <- phylo_data(x, "html", delete = "const", join = TRUE))
#' stopifnot(longer(y.noconst, y.nouninf))
#'
#' # getting real numbers, not discretised ones
#' echo(yy <- phylo_data(vaas_4[, , 1:10], as.labels = "Species",
#'   format = "html", join = TRUE, extract.args = list(in.parens = FALSE),
#'   subset = "A", discrete.args = NULL,
#'   html.args = html_args(organisms.start = "Species: ")))
#' stopifnot(is_html(yy), length(yy) == length(y) - 1) # no symbols list
#' # the highlighting is also used here, based on the following heuristic:
#' # if mean+/-2*sd does not overlap, the character is informative; else
#' # if mean+/-sd does not overlap, the character is uninformative; otherwise
#' # it is constant
#'
#' # this can also be used for formats other than HTML (but not all make sense)
#' echo(yy <- phylo_data(vaas_4[, , 1:10], as.labels = "Species",
#'   format = "hennig", join = TRUE, extract.args = list(in.parens = FALSE),
#'   subset = "A", discrete.args = NULL))
#' stopifnot(is.character(yy), length(yy) > 10)
#'
#' ## 'OPMD_Listing' method
#' echo(x <- phylo_data(listing(vaas_1, NULL)))
#' stopifnot(is.character(x), length(x) == 1)
#' echo(x <- phylo_data(listing(vaas_1, NULL, html = TRUE)))
#' stopifnot(is.character(x), length(x) > 1)
#'
#' ## 'OPMS_Listing' method
#' echo(x <- phylo_data(listing(vaas_4, as.groups = "Species")))
#' stopifnot(is.character(x), length(x) == 2, !is.null(names(x)))
#' echo(x <- phylo_data(listing(vaas_4, as.groups = "Species", html = TRUE)))
#' stopifnot(is.character(x), length(x) > 2, is.null(names(x)))
#'
setGeneric("phylo_data", function(object, ...) standardGeneric("phylo_data"))

setMethod("phylo_data", "matrix", function(object,
    format = opm_opt("phylo.fmt"), outfile = "", enclose = TRUE, indent = 3L,
    paup.block = FALSE, delete = c("none", "uninf", "constant", "ambig"),
    join = FALSE, cutoff = 0, digits = opm_opt("digits"),
    comments = comment(object), html.args = html_args(),
    prefer.char = format == "html", run.tidy = FALSE, ...) {
  format <- match.arg(format, PHYLO_FORMATS)
  delete <- match.arg(delete)
  comments <- comments
  object <- new("CMAT", object)
  if (L(prefer.char))
    object <- update(object, how = "NA2int")
  object <- merge(x = object, y = join)
  if (is.list(object) && L(cutoff) > 0)
    object[] <- lapply(object, reduce_to_mode.default, cutoff, FALSE)
  switch(EXPR = delete, none = NULL,
    object <- update(object, how = sprintf("delete.%s", delete)))
  result <- format(x = object, how = format, enclose = enclose, digits = digits,
    indent = indent, paup.block = paup.block, comments = comments,
    html.args = html.args, ...)
  if (L(run.tidy) && format == "html")
    result <- tidy(result, check = FALSE)
  if (nzchar(L(outfile))) {
    write(result, outfile)
    return(invisible(result))
  }
  result
}, sealed = SEALED)

setMethod("phylo_data", "data.frame", function(object, as.labels = NULL,
    subset = "numeric", sep = " ", ...) {
  object <- extract_columns(object, as.labels = as.labels, what = subset,
    direct = FALSE, sep = sep)
  phylo_data(object, ...)
}, sealed = SEALED)

setMethod("phylo_data", "XOPMX", function(object, as.labels,
    subset = param_names("disc.name"), sep = " ", extract.args = list(),
    join = TRUE, discrete.args = list(range = TRUE, gap = TRUE), ...) {
  extract.args <- insert(as.list(extract.args), list(object = object,
    as.labels = as.labels, as.groups = NULL, subset = subset,
    dups = if (is.logical(join) && L(join))
      "ignore"
    else
      "warn", dataframe = FALSE, ci = FALSE, sep = sep), .force = TRUE)
  object <- do.call(extract, extract.args)
  if (!is.null(discrete.args) && !is.logical(object)) {
    discrete.args <- as.list(discrete.args)
    discrete.args$x <- object
    object <- do.call(discrete, discrete.args)
  }
  phylo_data(object = object, join = join, ...)
}, sealed = SEALED)

setOldClass("OPMD_Listing")

setMethod("phylo_data", "OPMD_Listing", function(object,
    html.args = html_args(), run.tidy = FALSE) {
  if (!attr(object, "html"))
    return(paste(object, collapse = " "))
  head <- sprintf("Character listing exported by %s",
    paste0(opm_string(version = TRUE), collapse = " version "))
  attr(head, opm_string()) <- TRUE
  head <- html_head(head, html.args$css.file,
    html.args[names(html.args) == "meta"], html.args$embed.css)
  x <- c(HTML_DOCTYPE, "<html>", head, "<body>", unname(object),
    "</body>", "</html>")
  if (L(run.tidy))
    x <- tidy(x, check = FALSE)
  x
}, sealed = SEALED)

setOldClass("OPMS_Listing")

setMethod("phylo_data", "OPMS_Listing", function(object,
    html.args = html_args(), run.tidy = FALSE) {
  prepare_headlines <- function(x) {
    x <- safe_labels(x, format = "html")
    x <- hmakeTag("span", data = x, class = "organism-name",
      title = "organism-name")
    hmakeTag("div", data = x, class = "headline", title = "headline")
  }
  if (!attr(object, "html"))
    return(apply(object, 1L, paste, collapse = " "))
  head <- sprintf("Character listings exported by %s",
    paste0(opm_string(version = TRUE), collapse = " version "))
  attr(head, opm_string()) <- TRUE
  head <- html_head(head, html.args$css.file,
    html.args[names(html.args) == "meta"], html.args$embed.css)
  x <- apply(object, 1L, paste, collapse = "\n")
  x <- as.vector(rbind(prepare_headlines(names(x)), x))
  x <- c(HTML_DOCTYPE, "<html>", head, "<body>", x, "</body>", "</html>")
  if (L(run.tidy))
    x <- tidy(x, check = FALSE)
  x
}, sealed = SEALED)


################################################################################


