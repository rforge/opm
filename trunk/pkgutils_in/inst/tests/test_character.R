library(testthat)
context("Testing the character functions of the pkgutils package")


################################################################################


## sections
## UNTESTED

## map_files
## UNTESTED

## map_filenames
test_that("we can create pairs of file names", {
  x <- paste0(letters[seq_len(4L)], ".txt")
  expect_warning(got <- map_filenames(x, "out", "test", "", -1L))
  expect_equal(dim(got), c(6L, 3L))
})

## clean_filenames
test_that("file names can be cleaned", {
  x <- c("a b/c/x-y-z.txt", "d--z/z?-z. .csv", "/xxx/y y/?_?-abcd*+.txt",
    "sapif89asdh_&#-*_asdfhu.---", "!$%&+()=?`")
  expect_that(got <- clean_filenames(x, demo = TRUE), shows_message())
  expect_equal(names(got), x[-1L])
  expect_equivalent(got, c("d--z/z-z.csv", "/xxx/y y/abcd.txt",
    "sapif89asdh-asdfhu", "__EMPTY__00001__"))
  expect_warning(got <- clean_filenames(c("", "a", "?"), demo = TRUE))
  expect_equal(names(got), "?")
})

