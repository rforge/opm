\name{ci_plot}
\alias{ci_plot}
\title{Plot point estimates with \acronym{CI}s}
\arguments{
  \item{object}{\code{\link{OPMS}} or \code{\link{MOPMX}}
  object or (rarely) a data frame. If an \code{\link{OPMS}}
  object, it is in most cases necessary to restrict the
  plates to at most about one dozen wells. See
  \code{\link{[}} for how to achieve this. This also means
  that care should be taken when applying this function to
  a \code{\link{MOPMX}} object.

  The data frame method is not normally directly called by
  an \pkg{opm} user but via the \code{\link{OPMS}} method,
  unless it is used after \code{\link{extract}} was applied
  to a data frame for calculating point estimates and
  confidence intervals from groups of observations. See
  there for details.

  Otherwise, the data frame should be as exported by the
  \code{\link{OPMS}} method of \code{\link{extract}} with
  \code{ci} set to \code{TRUE}. There must be a column
  named \code{\link{param_names}("split.at")} followed by
  columns with only numeric values. Columns before that
  split column, if any, are used for grouping. The rows
  must entirely comprise triplets representing (i) the
  point estimate, (ii) the lower and (iii) the upper
  confidence interval.}

  \item{as.labels}{List. Metadata to be joined and used to
  draw a legend.  Ignored if \code{NULL}.}

  \item{subset}{Character scalar. The parameter to plot.
  Only a single one can be selected. See
  \code{\link{param_names}} for the options.}

  \item{rowname.sep}{Character scalar. Used when joining
  explanatory columns into row labels of the plots.}

  \item{prop.offset}{Numeric scalar. A proportional offset
  that is added to the vertical range of the panels (after
  determining the maximum range among all panels to ensure
  consistency within the plot).}

  \item{align}{Character scalar. How to apply the offset;
  in addition to the default, \sQuote{left} and
  \sQuote{right} are possible.}

  \item{col}{Character scalar. Colour to be used.}

  \item{na.action}{Character scalar. What to do if a
  confidence interval contains \code{NA} values; one of
  \sQuote{ignore}, \sQuote{warn} and \sQuote{error}.}

  \item{draw.legend}{Logical scalar. Ignored if there are
  no explanatory columns.}

  \item{legend.field}{Two-element numeric vector. Indicates
  the panel in which the legend is drawn. Subsequent
  arguments work then relative to this panel.  If
  \code{legend.field} has less then two fields, the number
  of panels is set to 1 (the entire plot), and the legend
  is drawn relative to that.}

  \item{x}{Legend position, passed to \code{legend} from
  the \pkg{graphics} package. Ignored unless
  \code{draw.legend} is \code{TRUE}.}

  \item{xpd}{Logical scalar. Also passed to that function.}

  \item{vline}{Numeric scalar with the position on the
  y-axis of a vertical line to be drawn. Ignored if
  \code{NULL}.}

  \item{crr}{Numeric scalar (column-row-ratio) interpreted
  as number of columns per number of rows. Determines the
  arrangement of the subplots.}

  \item{...}{Optional arguments passed to \code{legend}, or
  arguments passed between the methods.}

  \item{split.at}{Character vector. See
  \code{\link{extract}}.}
}
\value{
  Character vector describing the plot's legend, returned
  invisibly, or list of such vectors.
}
\description{
  Draw point estimates with their confidence intervals.
  Used for comparing aggregated values together with their
  confidence intervals between plates. This method can in
  most cases \strong{not} be applied to entire plates but
  to selected wells only.
}
\details{
  The default placement of the legend is currently not
  necessarily very useful. When plotting entire
  \acronym{PM} plates, the \sQuote{mar} parameter of
  \code{par} most likely would need to be set to a lower
  value, but it is recommended to plot only subsets of
  plates, i.e. selected wells.
}
\examples{
x <- ci_plot(vaas_4[, , 1:3], as.labels = list("Species", "Strain"),
  subset = "A", x = "bottomright", legend.field = NULL)
# note that the values on the y axes are drawn to scale
x
stopifnot(is.character(x), identical(length(x), 4L))
# ... and that the return value contains the legend (even if it is not drawn)

## See also the examples for the data-frame method of extract().
}
\references{
  Vaas LAI, Sikorski J, Michael V, Goeker M, Klenk H-P.
  2012 Visualization and curve parameter estimation
  strategies for efficient exploration of Phenotype
  Microarray kinetics. \emph{PLoS ONE} \strong{7}, e34846.
}
\seealso{
  graphics::plot

  Other plotting-functions: \code{\link{heat_map}},
  \code{\link{level_plot}}, \code{\link{parallel_plot}},
  \code{\link{parallelplot}}, \code{\link{radial_plot}},
  \code{\link{summary}}, \code{\link{xy_plot}}
}
\keyword{hplot}

%% BEGIN INSERTION BY repair_S4_docu.rb
\docType{methods}
\alias{ci_plot-methods}
\alias{ci_plot,MOPMX-method}
\alias{ci_plot,OPMS-method}
\alias{ci_plot,data.frame-method}
\usage{
  \S4method{ci_plot}{MOPMX}(object, ...) 
  \S4method{ci_plot}{OPMS}(object, as.labels,
    subset = opm_opt("curve.param"), ...) 
  \S4method{ci_plot}{data.frame}(object, rowname.sep = " ",
    prop.offset = 0.04, align = "center", col = "blue", na.action = "warn",
    draw.legend = TRUE, legend.field = c(1, 1), x = "topleft", xpd = TRUE,
    vline = 0, split.at = param_names("split.at"), crr = 0.75, ...) 
}
%% END INSERTION BY repair_S4_docu.rb
