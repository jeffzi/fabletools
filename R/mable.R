#' Create a new mable
#' 
#' A mable (model table) data class (`mdl_df`) is a tibble-like data structure 
#' for applying multiple models to a dataset. Each row of the mable refers to a
#' different time series from the data (identified by the key columns). A mable
#' must contain at least one column of time series models (`mdl_ts`), where the
#' list column itself (`lst_mdl`) describes how these models are related.
#' 
#' @inheritParams tibble::tibble
#' 
#' @param key Structural variable(s) that identify each model.
#' @param model Identifiers for the columns containing model(s).
#' @param models Deprecated in favour of the model argument.
#'
#' @export
mable <- function(..., key = NULL, model = NULL, models = NULL){
  if(!is_null(models)){
    warn("The models argument in `mable()` is deprecated. Please use `model()` instead.")
    model <- models
  }
  as_mable(tibble(...), key = !!enquo(key), model = !!enquo(model))
}


#' Is the object a mable
#' 
#' @param x An object.
#' 
#' @export
is_mable <- function(x){
  inherits(x, "mdl_df")
}

#' Coerce a dataset to a mable
#' 
#' @param x A dataset containing a list model column.
#' @param ... Additional arguments passed to other methods.
#' 
#' @rdname as_mable
#' @export
as_mable <- function(x, ...){
  UseMethod("as_mable")
}

#' @rdname as_mable
#' 
#' @inheritParams mable
#' 
#' @export
as_mable.data.frame <- function(x, key = NULL, model = NULL, models = NULL, ...){
  if(!is_null(models)){
    warn("The `models` argument in `mable()` is deprecated. Please use `model` instead.")
    model <- models
  }
  build_mable(x, key = !!enquo(key), model = !!enquo(model))
}

build_mable <- function (x, key = NULL, key_data = NULL, model) {
  model <- tidyselect::vars_select(names(x), !!enquo(model))
  
  if(length(unique(map(x[model], function(mdl) mdl[[1]]$response))) > 1){
    abort("A mable can only contain models with the same response variable(s).")
  }
  
  if (!is_null(key_data)){
    assert_key_data(key_data)
    key <- head(names(key_data), -1L)
  }
  else {
    key <- tidyselect::vars_select(names(x), !!enquo(key))
    key_data <- group_data(group_by(x, !!!syms(key)))
  }
  
  if(any(map_int(key_data[[length(key_data)]], length) > 1)){
    abort("The result is not a valid mable. The key variables must uniquely identify each row.")
  }
  
  tibble::new_tibble(x, key = key_data, model = model,
                     nrow = NROW(x), class = "mdl_df", subclass = "mdl_df")
}

#' @export
as_tibble.mdl_df <- function(x, ...){
  attr(x, "key") <- attr(x, "model") <- NULL
  class(x) <- c("tbl_df", "tbl", "data.frame")
  as_tibble(x, ...)
}

tbl_sum.mdl_df <- function(x){
  out <- c(`A mable` = paste(map_chr(dim(x), big_mark), collapse = " x "))
  
  if(!is_empty(key(x))){
    out <- c(out, c("Key" = sprintf("%s [%s]",
                                    paste0(key_vars(x), collapse = ", "),
                                    map_chr(n_keys(x), big_mark))))
  }
  
  out
}

#' @export
gather.mdl_df <- function(data, key = "key", value = "value", ..., na.rm = FALSE,
                          convert = FALSE, factor_key = FALSE){
  value <- enexpr(value)
  tbl <- gather(as_tibble(data), key = !!key, value = !!value, 
                ..., na.rm = na.rm, convert = convert, factor_key = factor_key)
  mdls <- names(which(map_lgl(tbl, inherits, "lst_mdl")))
  kv <- c(key_vars(data), key)
  as_mable(tbl, key = kv, model = mdls)
}

# Adapted from tsibble:::select_tsibble
#' @export
select.mdl_df <- function (.data, ...){
  sel_data <- NextMethod()
  sel_vars <- names(sel_data)
  
  kv <- key_vars(.data)
  key_vars <- intersect(sel_vars, kv)
  key_nochange <- all(is.element(kv, key_vars))
  
  mdls <- names(which(map_lgl(sel_data, inherits, "lst_mdl")))
  if(is_empty(mdls)){
    abort("A mable must contain at least one model. To remove all models, first convert to a tibble with `as_tibble()`.")
  }
  build_mable(sel_data,
              key = if(key_nochange) NULL else key_vars,
              key_data = if(key_nochange) key_data(.data) else NULL,
              model = mdls)
}

#' @export
`$<-.mdl_df` <- function (x, name, value) {
  tbl <- NextMethod()
  mdls <- names(which(map_lgl(tbl, inherits, "lst_mdl")))
  as_mable(tbl, key = key_vars(x), model = mdls)
}

#' @export
rename.mdl_df <- function (.data, ...){
  kv <- key_data(.data)
  .data <- NextMethod()
  mdls <- names(which(map_lgl(.data, inherits, "lst_mdl")))
  build_mable(.data, key_data = kv, model = mdls)
}

#' @export
mutate.mdl_df <- function (.data, ...){
  kv <- key_data(.data)
  .data <- NextMethod()
  
  mdls <- names(which(map_lgl(.data, inherits, "lst_mdl")))
  if(is_empty(mdls)){
    abort("A mable must contain at least one model. To remove all models, first convert to a tibble with `as_tibble()`.")
  }
  build_mable(.data, key_data = kv, model = mdls)
}

#' @export
group_data.mdl_df <- function(.data){
  .data <- as_tibble(.data)
  NextMethod()
}

#' @export
filter.mdl_df <- function (.data, ...){
  key <- key_vars(.data)
  mdls <- .data%@%"model"
  .data <- NextMethod()
  as_mable(.data, key = key, model = mdls)
}

#' @export
key_data.mdl_df <- function(x){
  x%@%"key"
}

#' @export
key_vars.mdl_df <- function(x){
  keys <- key_data(x)
  names(keys)[-NCOL(keys)]
}

#' @export
key.mdl_df <- function(x){
  syms(key_vars(x))
}
