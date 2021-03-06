#Package, build thine self
#'@importFrom utils install.packages
GRANonGRAN = function(repo)
{
    logfun(repo)("GRAN", paste("Creating repository specific GRAN package and",
                                "installing it into the GRAN repository at",
                                destination(repo)))

    tmpdir = repobase(repo)
    pkgname = paste0("GRAN", repo_name(repo))
    babyGRAN = file.path(tmpdir, pkgname)
    if(file.exists(babyGRAN))
        unlink(babyGRAN, recursive=TRUE, force=TRUE)
    dirs = file.path(babyGRAN, c("inst/scripts", "R", "man", "vignettes"))
    sapply(dirs, dir.create, recursive = TRUE)
    GRANRepo = repo
    fils = list.files(system.file2("GRAN", package="GRANBase"), recursive=TRUE)
    res = file.copy(file.path(system.file2("GRAN", package="GRANBase"), fils),
              file.path(babyGRAN, fils), overwrite=TRUE)

    if(any(!res))
        stop("copy failed")
    saveRepo(GRANRepo,
         filename = file.path(babyGRAN, "inst", "myrepo.R"))
    code = paste("getGRAN = function(...) {",
        sprintf("install.packages('%s', ..., repos = c('%s', getOption('repos')))",
                pkgname, repo_url(repo)),
        "};", "getGRAN(type='source')", collapse = "\n")
    cat(code, file = file.path(babyGRAN, "inst", "scripts", "getGRAN.R"))
    cat(code, file = file.path(dest_base(repo), paste0("getGRAN-", repo_name(repo), ".R")))
    DESC = readLines(file.path(babyGRAN, "DESCRIPTION"))
    DESC[1] = paste0("Package: ", pkgname)
    writeLines(DESC, con = file.path(babyGRAN, "DESCRIPTION"))
    cat(paste0("pkgname = '", pkgname, "'"), file = file.path(babyGRAN, "R", "00packagename.R"))

    ## if(pkgname %in% manifest_df(repo)$name) {
    ##     granInd = which(repo_results(repo)$name == pkgname)
    ##     repo_results(repo)[granInd,] = ResultsRow(name = pkgname)
    ##     manifest_df(repo)[granInd,] = ManifestRow(name=pkgname,
    ##                          url = babyGRAN, type="local", subdir = ".",
    ##                          branch = "master")
    ## } else {
    ##     repo = addPkg(repo, name=pkgname, url = babyGRAN, type="local",
    ##         subdir = ".")
    ## }

    repo = addPkg(repo, name=pkgname, url = babyGRAN, type="local",
                  subdir = ".", replace = TRUE)
    ## addPkg doesn't reset the results
    granInd = which(repo_results(repo)$name == pkgname)
    repo_results(repo)[granInd,] = ResultsRow(name = pkgname)

    ##    cran_use_ok = use_cran_granbase(repo)
    cran_use_ok = FALSE
    if(cran_use_ok) {
        ## this should give us GRANBase, switchr, and dependencies

        ## can't test it without it being on CRAN though :-/
        res = tryCatch(install.packages("GRANBase", dependencies=TRUE, lib = temp_lib(repo)),
            error = function(e) e)
        if(is(res, "error"))
            cran_use_ok = FALSE
    }

    if(!cran_use_ok) { ## force switchr and GRANBase into the manifest and make them build
        pkgs = c("switchr", "GRANBase")
        repo = addPkg(repo,
                      name = pkgs,
                      url = c("https://github.com/gmbecker/switchr",
                              "https://github.com/gmbecker/gRAN"),
                      type = "git", replace=TRUE)

        df = repo_results(repo)
        df[df$name %in% pkgs, "building"] = TRUE
        df[df$name %in% pkgs, "lastbuiltversion"] = "0.0-0"

        repo_results(repo) = df
    }


    repo


}

#'Transform a GRANRepository object into a list
#'
#' Utility to transform a GRANRepository object into a list
#' so that repos saved using GRANBase can be loaded by GRAN
#' without requiring GRANBase
#'
#' @param repo repository
#' @return a list suitable for use with RepoFromList
#' @export
RepoToList = function(repo) {

    sl = names(getSlots(class(repo)))
    l = lapply(sl, function(x) slot(repo, x))
    names(l) = sl
    l
}

#'Create a GRANRepository object from a list
#'
#' @param rlist A list with entries that are slot name-value
#' pairs for a GRANRepository object
#' @return a GRANRepository object
#' @export
RepoFromList = function(rlist) {
    do.call(new, c("GRANRepository", rlist))
}

#'Backwards compatible load utility
#'
#' Load a repository serialized to an R code file
#'
#' @param filename The file to load
#' @export
loadRepo = function(filename) {
    res = tryCatch(dget(filename), error = function(e)e)
    if(is(res, "error")) {
        txt = readLines(filename)
        txt2 = gsub("GRANRepository", "GRANRepositoryv0.9", txt)
        res = dget(textConnection(txt2))
        res = updateGRANRepoObject(res)
    }
    ## Just in case
    prepDirStructure(normalizePath2(file.path(repobase(res), "..")),
                     repo_name(res),
                     temp_repo(res),
                     checkout_dir(res),
                     temp_lib(res),
                     dest_base(res))

    ##refresh closure for log function
    logfun(res) = function(pkg, msg, type = "full") writeGRANLog(pkg, msg, type,
              logfile = logfile(res), errfile = errlogfile(res),
              pkglog = pkg_log_file(pkg, res))
    res
}


#'Backwards compatible save utility
#'
#' serialize a repository to a file so that it does not require GRANBase
#' to load
#'
#' @param repo The GRANRepository object to save
#' @param filename The destination file
#' @return NULL
#' @export
saveRepo = function(repo, filename) {
   dput(repo, filename)
}
