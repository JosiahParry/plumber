context("Plumber")

exec_endpoint <- function(pr, ep_pos, subset = 1) {
  # This is a poor setup of `req` and `res`. But it works for testing purposes
  pr$endpoints[[subset]][[ep_pos]]$exec(make_req(), PlumberResponse$new())
}

test_that("Endpoints are properly identified", {
  r <- pr(test_path("files/endpoints.R"))
  expect_equal(length(r$endpoints), 1)
  expect_equal(length(r$endpoints[[1]]), 5)
  expect_equal(exec_endpoint(r, 1), 5)
  expect_equal(exec_endpoint(r, 2), 5)
  expect_equal(exec_endpoint(r, 3), 10)
  expect_equal(exec_endpoint(r, 4), 12)
  expect_equal(exec_endpoint(r, 5), 14)
})

test_that("Empty file argument is OK", {
  r <- pr()
  expect_equal(length(r$endpoints), 0)
})

test_that("Empty file is OK", {
  f <- tempfile()
  writeLines(character(), f)
  on.exit(unlink(f), add = TRUE)
  r <- pr(f)
  expect_equal(length(r$endpoints), 0)
})

test_that("The file is sourced in the envir", {
  r <- pr(test_path("files/in-env.R"))
  expect_equal(length(r$endpoints), 1)
  expect_equal(length(r$endpoints[[1]]), 2)
  expect_equal(exec_endpoint(r, 1), 15)
})

test_that("Verbs translate correctly", {
  r <- pr(test_path("files/verbs.R"))
  expect_equal(length(r$endpoints), 1)
  expect_equal(length(r$endpoints[[1]]), 10)
  expect_equal(r$endpoints[[1]][[1]]$verbs, c("GET", "PUT", "POST", "DELETE", "HEAD", "OPTIONS", "PATCH"))
  expect_equal(r$endpoints[[1]][[2]]$verbs, "GET")
  expect_equal(r$endpoints[[1]][[3]]$verbs, "PUT")
  expect_equal(r$endpoints[[1]][[4]]$verbs, "POST")
  expect_equal(r$endpoints[[1]][[5]]$verbs, "DELETE")
  expect_equal(r$endpoints[[1]][[6]]$verbs, "POST")
  expect_equal(r$endpoints[[1]][[7]]$verbs, "GET")
  expect_equal(r$endpoints[[1]][[8]]$verbs, "HEAD")
  expect_equal(r$endpoints[[1]][[9]]$verbs, "OPTIONS")
  expect_equal(r$endpoints[[1]][[10]]$verbs, "PATCH")
})

test_that("Invalid file fails gracefully", {
  expect_error(pr("asdfsadf"), regexp="File does not exist.*asdfsadf")
})

test_that("plumb accepts a file", {
  r <- plumb(test_path("files/endpoints.R"))
  expect_length(r$endpoints[[1]], 5)
})

test_that("plumb gives a good error when passing in a dir instead of a file", {

  # brittle test. Fails on r-devel-windows-x86_64-gcc10-UCRT
  skip_on_cran()

  expect_error(plumb(test_path("files/")), "Expecting a file but found a directory: 'files")
})

test_that("plumb accepts a directory with a `plumber.R` file", {
  # works without trailing slash
  r <- plumb(dir = test_path('files'))
  expect_equal(length(r$endpoints), 1)
  expect_equal(length(r$endpoints[[1]]), 5)

  # works with trailing slash
  r <- plumb(dir = paste0(test_path('files'), "/"))
  expect_equal(length(r$endpoints), 1)
  expect_equal(length(r$endpoints[[1]]), 5)

  # errors when no plumber.R found
  expect_error(plumb(dir = test_path("files/static")), regexp="No plumber.R file found in the specified directory: ")

  # errors when neither dir is empty and file is not given
  expect_error(plumb(dir=""), regexp="You must specify either a file or directory*")

  # reads from working dir if no args
  expect_error(plumb(), regexp="No plumber.R file found in the specified directory: .")

  # errors when both dir and file are given
  expect_silent(plumb(file = "endpoints.R", dir = test_path("files")))

})

test_that("plumb() a dir leverages `entrypoint.R`", {

  with_tmp_serializers({
    expect_false(
      "fake" %in% registered_serializers(),
      "This just that your Plumber environment is dirty. Restart your R session."
    )

    r <- plumb(dir = test_path("files/entrypoint/"))
    expect_equal(length(r$endpoints), 1)
    expect_equal(length(r$endpoints[[1]]), 1)

    # A global serializer was added by entrypoint.R before parsing
    expect_true(
      "fake" %in% registered_serializers(),
      "This just that your Plumber environment is dirty. Restart your R session."
    )
  })

  expect_false(
    "fake" %in% registered_serializers(),
    "This just that your Plumber environment is dirty. Restart your R session."
  )
})

test_that("bad `entrypoint.R`s throw", {
  expect_error(plumb(dir = test_path("files/entrypoint-bad/")), "runnable Plumber router")
})

test_that("plumb() a dir works with `entrypoint.R` and without `plumber.R`", {
  r <- plumb(dir = test_path("files/no-plumber/"))
  expect_equal(length(r$endpoints), 1)
  expect_equal(length(r$endpoints[[1]]), 1)
})

test_that("Empty endpoints error", {
  expect_error(pr(test_path("files/endpoints-empty.R")), regexp="No path specified")
})

test_that("The old roxygen-style comments work", {
  r <- pr(test_path("files/endpoints-old.R"))
  expect_equal(length(r$endpoints), 1)
  expect_equal(length(r$endpoints[[1]]), 5)
  expect_equal(exec_endpoint(r, 1), 5)
  expect_equal(exec_endpoint(r, 2), 5)
  expect_equal(exec_endpoint(r, 3), 10)
  expect_equal(exec_endpoint(r, 4), 12)
  expect_equal(exec_endpoint(r, 5), 14)
})

test_that("routes can be constructed correctly", {
  pr <- pr()
  pr$handle("GET", "/nested/path/here", function(){})
  pr$handle("POST", "/nested/path/here", function(){})

  pr2 <- pr()
  pr2$handle("POST", "/something", function(){})
  pr2$handle("GET", "/", function(){})
  pr$mount("/mysubpath", pr2)

  stat <- PlumberStatic$new(".")
  pr$mount("/static", stat)

  pr3 <- pr()
  pr_get(pr3, "a/b", function(){})
  pr_get(pr3, "a", function(){})
  expect_length(pr3$routes$a, 2)

  pr4 <- pr()
  pr_get(pr4, "a", function(){})
  pr_post(pr4, "a/b/c/f", function(){})
  pr_get(pr4, "a/b/c/f", function(){})
  pr_get(pr4, "a/b/c/f/g/h/j/k", function(){})
  pr_get(pr4, "v/b/c/f", function(){})
  pr_get(pr4, "v/b/c/b", function(){})
  pr_get(pr4, "v/b/c/a", function(){})
  pr_get(pr4, "t", function(){})
  pr_post(pr4, "u/b/c/f", function(){})
  pr_get(pr4, "i/b/c/f/g/h/j/k", function(){})
  expect_equal(names(pr4$routes), c("a", "a", "i", "t", "u", "v"))
  expect_equal(names(pr4$routes$v$b$c), c("a", "b", "f"))

  expect_length(pr$routes, 3)
  expect_s3_class(pr$routes[["static"]], "PlumberStatic")
  expect_s3_class(pr$routes[["mysubpath"]], "Plumber")

  # 2 endpoints at the same location (different verbs)
  expect_length(pr$routes$nested$path$here, 2)
})

test_that("mounts can be read correctly", {
  pr <- pr()
  pr$handle("GET", "/nested/path/here", function(){})
  pr$handle("POST", "/nested/path/here", function(){})

  pr2 <- pr()
  pr2$handle("POST", "/something", function(){})
  pr2$handle("GET", "/", function(){})
  pr$mount("/mysubpath", pr2)

  stat <- PlumberStatic$new(".")
  pr$mount("/static", stat)
  pr$mount("missing-slashes", stat)
  pr$mount("/both-slashes/", stat)
  pr$mount("trailing-slash/", stat)
  pr$mount("/extra-slash//", stat)

  expect_length(pr$routes, 7)
  expect_s3_class(pr$mounts[["/static/"]], "PlumberStatic")
  expect_s3_class(pr$mounts[["/missing-slashes/"]], "PlumberStatic")
  expect_s3_class(pr$mounts[["/both-slashes/"]], "PlumberStatic")
  expect_s3_class(pr$mounts[["/trailing-slash/"]], "PlumberStatic")
  expect_s3_class(pr$mounts[["/extra-slash//"]], "PlumberStatic")
  expect_s3_class(pr$mounts[["/mysubpath/"]], "Plumber")
})



test_that("mounts work", {
  pr <- pr()
  sub <- pr()
  sub$handle("GET", "/", function(){ 1 })
  sub$handle("GET", "/nested/path", function(a){ a })

  pr$mount("/subpath", sub)

  res <- PlumberResponse$new()
  pr$route(make_req("GET", "/nested/path"), res)
  expect_equal(res$status, 404)

  val <- pr$route(make_req("GET", "/subpath/nested/path", qs="?a=123"), PlumberResponse$new())
  expect_equal(val, "123")

  val <- pr$route(make_req("GET", "/subpath/nested/path", body='{"a":123}'), PlumberResponse$new())
  expect_equal(val, 123)

  val <- pr$route(make_req("GET", "/subpath/"), PlumberResponse$new())
  expect_equal(val, 1)
})

test_that("mounting at root path works", {
  pr <- pr()
  sub <- pr()
  sub$handle("GET", "/", function(){ 1 })
  sub$handle("GET", "/nested/path", function(){ 2 })

  pr$mount("/", sub)

  val <- pr$route(make_req("GET", "/nested/path"), PlumberResponse$new())
  expect_equal(val, 2)

  val <- pr$route(make_req("GET", "/"), PlumberResponse$new())
  expect_equal(val, 1)
})

test_that("conflicting mounts behave consistently", {
  pr <- pr()

  sub <- pr()
  sub$handle("GET", "/", function(){ 1 })
  pr$mount("/subpath", sub)

  val <- pr$route(make_req("GET", "/subpath/"), PlumberResponse$new())
  expect_equal(val, 1)

  pr$handle("GET", "/subpath/", function(){ 2 })

  val <- pr$route(make_req("GET", "/subpath/"), PlumberResponse$new())
  expect_equal(val, 2)
})

test_that("hooks can be registered", {
  pr <- pr()
  events <- NULL
  pr$handle("GET", "/", function(){ events <<- c(events, "exec") })
  pr$registerHook("preroute", function(){ events <<- c(events, "preroute") })
  pr$registerHook("postroute", function(){ events <<- c(events, "postroute") })
  pr$registerHook("preserialize", function(){ events <<- c(events, "preserialize") })
  pr$registerHook("postserialize", function(){ events <<- c(events, "postserialize") })

  pr$call(make_req("GET", "/"))
  expect_equal(events, c("preroute", "exec", "postroute", "preserialize", "postserialize"))
})

test_that("preroute hook gets the right data", {
  pr <- pr()
  pr$handle("GET", "/", function(){ })
  rqst <- make_req("GET", "/")

  pr$registerHook("preroute", function(data, req, res){
    expect_s3_class(res, "PlumberResponse")
    expect_equal(rqst, req)
    expect_true(is.environment(data))
  })
  pr$call(rqst)
})

test_that("postroute hook gets the right data and can modify", {
  pr <- pr()
  pr$handle("GET", "/abc", function(){ 123 })

  pr$registerHook("postroute", function(data, req, res, value){
    expect_s3_class(res, "PlumberResponse")
    expect_equal(req$PATH_INFO, "/abc")
    expect_true(is.environment(data))
    expect_equal(value, 123)
    "new val"
  })
  res <- pr$call(make_req("GET", "/abc"))
  expect_equal(as.character(res$body), '["new val"]')
})

test_that("preserialize hook gets the right data and can modify", {
  pr <- pr()
  pr$handle("GET", "/abc", function(){ 123 })

  pr$registerHook("preserialize", function(data, req, res, value){
    expect_s3_class(res, "PlumberResponse")
    expect_equal(req$PATH_INFO, "/abc")
    expect_true(is.environment(data))
    expect_equal(value, 123)
    "new val"
  })
  res <- pr$call(make_req("GET", "/abc"))
  expect_equal(as.character(res$body), '["new val"]')
})

test_that("postserialize hook gets the right data and can modify", {
  pr <- pr()
  pr$handle("GET", "/abc", function(){ 123 })

  pr$registerHook("postserialize", function(data, req, res, value){
    expect_s3_class(res, "PlumberResponse")
    expect_equal(req$PATH_INFO, "/abc")
    expect_true(is.environment(data))
    expect_equal(as.character(value$body), "[123]")
    value$body <- "new val"
    value
  })
  res <- pr$call(make_req("GET", "/abc"))
  expect_equal(as.character(res$body), 'new val')
})

test_that("invalid hooks err", {
  pr <- pr()
  expect_error(pr$registerHook("flargdarg"))
})

test_that("handle invokes correctly", {
  with_options(
    list(plumber.trailingSlash = NULL),
    {
      pr <- pr()
      pr$handle("GET", "/trailslash", function(){ "getter" })
      pr$handle("POST", "/trailslashp/", function(){ "poster" })

      expect_equal(pr$call(make_req("GET", "/trailslash"))$body, jsonlite::toJSON("getter"))
      res <- pr$call(make_req("GET", "/trailslash/")) # With trailing slash
      expect_equal(res$status, 404)
      res <- pr$call(make_req("POST", "/trailslash")) # Wrong verb
      expect_equal(res$status, 405)

      expect_equal(pr$call(make_req("POST", "/trailslashp/"))$body, jsonlite::toJSON("poster"))
      res <- pr$call(make_req("POST", "/trailslashp")) # w/o trailing slash
      expect_equal(res$status, 404)
      res <- pr$call(make_req("GET", "/trailslashp/")) # Wrong verb
      expect_equal(res$status, 405)
    }
  )

})

test_that("trailing slashes are redirected", {

  pr <- pr() %>%
    pr_get("/get/", function(a) a) %>%
    pr_post("/post/", function(a) a) %>%
    pr_mount(
      "/mnt",
      pr() %>%
        pr_get("/", function(a) a)
    )

  with_options(list(plumber.trailingSlash = FALSE), {
    res <- pr$call(make_req("GET", "/get", "?a=1"))
    expect_equal(res$status, 404)

    res <- pr$call(make_req("POST", "/post", "?a=1"))
    expect_equal(res$status, 404)

    res <- pr$call(make_req("GET", "/mnt", "?a=1"))
    expect_equal(res$status, 404)
  })

  with_options(list(plumber.trailingSlash = TRUE), {
    res <- pr$call(make_req("GET", "/get", "?a=1"))
    expect_equal(res$status, 307)
    expect_equal(res$headers$Location, "/get/?a=1")

    res <- pr$call(make_req("POST", "/post", "?a=1"))
    expect_equal(res$status, 307)
    expect_equal(res$headers$Location, "/post/?a=1")

    res <- pr$call(make_req("GET", "/mnt", "?a=1"))
    expect_equal(res$status, 307)
    expect_equal(res$headers$Location, "/mnt/?a=1")
  })
})


test_that("No 405 on same path, different verb", {

  pr <- pr()
  pr$handle("GET", "/apathow", function(){ "getter" })
  pr$handle("POST", "/apathow", function(){ "poster" })

  expect_equal(pr$route(make_req("GET", "/apathow"), PlumberResponse$new()), "getter")
  expect_equal(pr$route(make_req("POST", "/apathow"), PlumberResponse$new()), "poster")

})

test_that("handle with an endpoint works", {
  pr <- pr()
  ep <- PlumberEndpoint$new("GET", "/", function(){ "manual endpoint" }, pr$environment, serializer_json())
  pr$handle(endpoint=ep)

  val <- pr$route(make_req("GET", "/"), PlumberResponse$new())
  expect_equal(val, "manual endpoint")
})

test_that("handle with and enpoint and endpoint def fails", {
  pr <- pr()
  ep <- PlumberEndpoint$new("GET", "/", function(){ "manual endpoint" }, pr$environment, serializer_json())
  expect_error(pr$handle("GET", "/", endpoint=ep))
})

test_that("full handle call works", {
  pr <- pr()
  pr$filter("f1", function(req){ req$filtered <- TRUE; forward() })

  pr$handle("GET", "/preempt", function(req){
    expect_null(req$filtered)
    "preempted"
  }, "f1", serializer_unboxed_json())

  pr$handle("GET", "/dontpreempt", function(req){
    expect_true(req$filtered)
    "unpreempted"
  }, serializer=serializer_unboxed_json())

  res <- PlumberResponse$new()
  val <- pr$route(make_req("GET", "/preempt"), res)
  expect_equal(val, "preempted") # no JSON box
  res <- PlumberResponse$new()
  val <- pr$route(make_req("GET", "/dontpreempt"), res)
  expect_equal(val, "unpreempted") # no JSON box
})

test_that("Expressions and functions both work on handle", {
  pr <- pr()
  pr$handle("GET", "/function", function(req){ req[["PATH_INFO"]] })
  pr$handle("GET", "/expression", expression(function(req){ req[["PATH_INFO"]] }))

  val <- pr$route(make_req("GET", "/function"), PlumberResponse$new())
  expect_equal(val, "/function")
  val <- pr$route(make_req("GET", "/expression"), PlumberResponse$new())
  expect_equal(val, "/expression")
})

test_that("Expressions and functions both work on filter", {
  pr <- pr()
  pr$filter("ff", function(req){ req$filteredF <- TRUE; forward() })
  pr$filter("fe", expression(function(req){ req$filteredE <- TRUE; forward() }))
  pr$handle("GET", "/", function(req){
    req$filteredE && req$filteredF
  })

  val <- pr$route(make_req("GET", "/"), PlumberResponse$new())
  expect_true(val)

  pr$handle("GET", "/expr", expression(function(req){
    req$filteredE && req$filteredF
  }))

  val <- pr$route(make_req("GET", "/expr"), PlumberResponse$new())
  expect_true(val)
})

test_that("filters and endpoint expressions evaluated in the appropriate (possibly injected) environment", {
  # Create an environment that contains a variable named `y`.
  env <- new.env(parent=.GlobalEnv)
  env$y <- 10

  # We provide expressions so that they get closurified in the right environment
  # and will be able to find `y`.
  # This would all fail without an injected environment that contains `y`.
  pr <- pr(envir=env)
  pr$filter("ff", expression(function(req){ req$ys <- y^2; forward() }))
  pr$handle("GET", "/", expression(function(req){ paste(y, req$ys) }))

  # Send a request through and we should see an assign to our env.
  val <- pr$route(make_req("GET", "/"), PlumberResponse$new())
  expect_equal(val, "10 100")
})

test_that("filters and endpoints executed in the appropriate environment", {
  # We've already seen that, if expressions, they're going to be evaluated in the
  # appropriate environment, but we can also confirm that once they've been evaluated,
  # they're then executed in the appropriate environment.

  # This almost certainly doesn't matter unless a function is inspecting the call stack,
  # but for the sake of consistency we not only ensure that any given expressions are
  # evaluated in the appropriate environment, but also that they are then called in the
  # given environment, as well.

  env <- new.env(parent=.GlobalEnv)

  pr <- pr(envir=env)
  pr$filter("ff", expression(function(req){ req$filterEnv <- parent.frame(); forward() }))
  pr$handle("GET", "/", expression(function(req){
    expect_identical(req$filterEnv, parent.frame())
    parent.frame()
  }))

  # Send a request through and we should see an assign to our env.
  val <- pr$route(make_req("GET", "/"), PlumberResponse$new())
  expect_identical(env, val)
})


test_that("host is updated properly for printing", {

  expect_identical(
    urlHost(host = "1:1:1", port = 1234),
    "http://[1:1:1]:1234"
  )
  expect_identical(
    urlHost(host = "::", port = 1234, changeHostLocation = FALSE),
    "http://[::]:1234"
  )
  expect_identical(
    urlHost(host = "::", port = 1234, changeHostLocation = TRUE),
    "http://[::1]:1234"
  )
  expect_identical(
    urlHost(host = "1.2.3.4", port = 1234),
    "http://1.2.3.4:1234"
  )
  expect_identical(
    urlHost(host = "0.0.0.0", port = 1234, changeHostLocation = FALSE),
    "http://0.0.0.0:1234"
  )
  expect_identical(
    urlHost(host = "0.0.0.0", port = 1234, changeHostLocation = TRUE),
    "http://127.0.0.1:1234"
  )
  expect_identical(
    urlHost(scheme = "http", host = "0.0.0.0", port = 1234, path = "/v1", changeHostLocation = TRUE),
    "http://127.0.0.1:1234/v1"
  )
})

test_that("unmount works", {
  pr <- pr()
  sub <- pr()
  sub$handle("GET", "/", function(){ 1 })
  sub$handle("GET", "/nested/path", function(){ 2 })
  pr$mount("/mount", sub)
  pr$mount("/mount2", sub)
  expect_equal(names(pr$mounts), c("/mount/", "/mount2/"))
  expect_invisible(pr$unmount("/henry"))
  expect_invisible(pr$unmount("/mount2/"))
  expect_equal(names(pr$mounts), "/mount/")
})

test_that("removeHandle works", {
  pr <- pr()
  pr$handle("GET", "/path1", function(){ 1 })
  pr$handle("GET", "/path2", function(){ 2 })
  expect_equal(length(pr$endpoints[[1]]), 2L)
  expect_invisible(pr$removeHandle("GET", "/path1"))
  expect_equal(length(pr$endpoints[[1]]), 1L)
  expect_equal(pr$endpoints[[1]][[1]]$path, "/path2")
})


test_that("routes that don't start with a slash are prepended with a slash", {
  pr <- pr()
  pr$handle("GET", "nested/path/here", function(){})

  expect_equal(length(pr$endpoints[[1]]), 1L)
  expect_equal(pr$endpoints[[1]][[1]]$path, "/nested/path/here")
})

test_that("handle method rejects forbidden arguments", {
  pr <- pr()
  expect_error(pr$handle("GET", "nested/path/here", function(){}, envir = new.env()),
               "can not be supplied to", )
  expect_error(pr$handle("GET", "nested/path/here", function(){}, verbs = "GET"),
               "can not be supplied to")
  expect_error(pr$handle("GET", "nested/path/here", function(){}, expr = function(){}),
               "can not be supplied to")
})
