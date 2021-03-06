#' @importFrom utils getParseData
build_pd <- function(code) {
  tryCatch(getParseData(parse(text = code, keep.source = TRUE), includeText = TRUE),
           error = function(e) return(NULL))
}

get_children <- function(pd, ids) {
  all_childs <- c()
  childs <- function(index){
    kids <- pd$id[ pd$parent %in% index ]
    if( length(kids) ){
      all_childs <<- c(all_childs, kids )
      childs( kids )
    }
  }
  sapply(ids, childs)
  return(all_childs)
}

get_sub_pd <- function(pd, ids) {
  children <- get_children(pd, ids)
  pd[pd$id %in% c(children, ids), ]
}

extract_assignments <- function(pd, name) {
  symbols <- pd[pd$token == "SYMBOL" & pd$text == name, ]
  assigns <- pd[pd$token %in% c("LEFT_ASSIGN", "RIGHT_ASSIGN", "EQ_ASSIGN"), ]
  
  if(nrow(assigns) == 0) return(NULL)
  
  sub_pds <- list()
  for(i in 1:nrow(assigns)) {
    assign <- assigns[i, ]
    valid_ids <- get_valid_ids(pd, assign, symbols)
    if(is.null(valid_ids)) next
    sub_pd <- get_sub_pd(pd, ids = valid_ids)
    sub_pds <- c(sub_pds, list(sub_pd))
  }
  
  return(sub_pds)
}

get_valid_ids <- function(pd, assign, symbols) {
  if(assign$token == "EQ_ASSIGN") {
    siblings <- pd$id[pd$parent == assign$parent]
    close_siblings <- siblings[which(siblings == assign$id) + c(-1, 1)]
    symbol_children <- intersect(union(get_children(pd, close_siblings), close_siblings), symbols$id)
  } else {
    symbol_children <- intersect(get_children(pd, assign$parent), symbols$id)  
  }
  assign_row <- which(pd$id == assign$id)
  children_rows <- which(pd$id %in% symbol_children)
  if(assign$token == "LEFT_ASSIGN") {
    if(any(children_rows < assign_row)) {
      return(assign$parent)
    } else {
      return(NULL)
    }
  } else if (assign$token == "RIGHT_ASSIGN") {
    if(any(children_rows > assign_row)) {
      return(assign$parent)
    } else {
      return(NULL)
    }
  } else if (assign$token == "EQ_ASSIGN") {
    if(any(children_rows < assign_row)) {
      return(c(close_siblings, assign$id)) 
    } else {
      return(NULL)  
    }
  } else {
    stop("token not supported")
  }
}


extract_object_assignment <- function(pd, name) {
  sub_pds <- extract_assignments(pd, name)
  if(length(sub_pds) == 1) {
    return(sub_pds[[1]])
  } else {
    return(NA)
  }
}

#' @importFrom utils tail getParseText
extract_function_definition <- function(pd, name) {
  # body of the function is the last brother of the function keyword
  sub_pds <- extract_assignments(pd, name)
  if(length(sub_pds) == 1) {
    pd <- sub_pds[[1]]
    function_parent <- pd$parent[pd$token == "FUNCTION"]
    if (length(function_parent) == 1) {
      last_brother <- tail(pd$id[pd$parent == function_parent], 1)
      code <- getParseText(pd, last_brother)
      sub_pd <- get_sub_pd(pd, last_brother)
      return(list(code = code, pd = sub_pd))
    } else {
      return(NULL)
    }
  } else {
    return(NULL)
  }
  
}