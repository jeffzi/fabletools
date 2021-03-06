#' @export
equation.mdl_df <- function(object, ...){
  if(NROW(object) > 1 || length(object%@%"model") > 1){
    abort("Model equations are only supported for individual models. To see the equation for a specific model, use `select()` and `filter()` to identify a single model.")
  }
  equation(object[[(object%@%"model")[[1]]]][[1]])
}

#' @export
equation.mdl_ts <- function(object, ...){
  if(any(!map_lgl(object$transformation, compose(is.name, body)))){
    abort("Cannot display equations containing transformations.")
  }
  equation(object[["fit"]])
}