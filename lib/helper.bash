#!/usr/bin/env bash

function upstream_remote() {
    local branch="${1:-$(git symbolic-ref HEAD)}"
    git for-each-ref "refs/heads/" --format="%(upstream:short)" | cut -d / -f 1
}

# Returns protocol, user, host and port on an array.
function splitURL() {
    local url=$1
    declare -ag $2="( $(echo $url | sed -E 's/^([[:alpha:]]+):\/\/(([[:print:]]+)@)?([^/:]*)(:([[:digit:]]+))?\/(.*)$/[0]="\1" [1]="\3" [2]="\4" [3]="\6" [4]="\7"/') )"
}

function split_remote() {
    local var=$1
    local remote=${2:-$(upstream_remote)}
    splitURL "$(git remote get-url $remote)" "$var"
}

function gerrit_url() {
    for remote in $(git remote); do git remote get-url $remote; done | grep ssh | sort | uniq
}

function gerrit() {
    splitURL $(gerrit_url) remote_url
    ssh -p ${remote_url[3]} ${remote_url[1]}@${remote_url[2]} gerrit "$@"
}

function getrevlist() {
    if [[ "$@" == "" ]]; then
        git rev-list --reverse "@{upstream}..HEAD"
    else
        git rev-list "$@"
    fi
}

function git-foreach() {

    declare -a execute__
    declare -a on_success__
    declare -a on_error__
    declare -a revlist__

    local current="revlist"
    local help="no"
    while [[ $# > 0 ]]; do
        local arg="$1"
        shift

        case "$arg" in
            --exec)
                current="exec"
                continue;;
            --on-success)
                current="success"
                continue;;
            --on-error)
                current="error"
                continue;;
            -h | --help | -\?)
                help="yes"
                continue;;
        esac

        case "$current" in
            exec)
                execute__+=("$arg");;
            success)
                on_success__+=("$arg");;
            error)
                on_error__+=("$arg");;
            revlist)
                revlist__+=("$arg");;
        esac
    done
    if [[ "$help" == "yes" || ${#execute__[@]} == 0 ]]; then
        cat <<EOF
usage: git-foreach [ rev-list parameters ] --exec <command to execute> --on-success <execute on success> --on-error <execute on error>

This command will run the "exec" command on the top level of the git work
directory for each commit returned by git-rev-list with the provided parameters.

Once the "exec" command is finished git-foreach will either execute the
"on-success" or "on-error" command depending on the exit status of the "exec"
command.  The processing will stop at the first error detected.

If no rev-list parameters are provided this will default to list all non-merged commits from
the current branch in chronological ordering. (git rev-list ${upstream}..HEAD)

EOF
        return 1
    fi

    (
        branch="$(git symbolic-ref --short HEAD)"

        function cleanup() {
            git checkout $branch
        }

        trap cleanup EXIT

        cd $(git rev-parse --show-toplevel)
        for commit in $(getrevlist "${revlist__[@]}"); do
            git checkout --detach $commit > /dev/null
            commitMsg='"'$(git log -1 --pretty=format:%s | cut -b "1-70" )'"'
            msg "processing $commitMsg"
            if eval "${execute__[@]}"; then
                msg $commitMsg Success
                eval "${on_success__[@]}";
            else
                msg $commitMsg Failled
                eval "${on_error__[@]}";
                break;
            fi
        done
    )
}

function msg() {
    echo
    echo ================================================================================
    echo "$@"
    echo ================================================================================
    echo
}

function gerrit_approvals() {
    gerrit query --format=json --all-approvals "$@" | head -n 1 | jq -r '.patchSets[-1].approvals[]? | .by.username + " " + .type? + ":" + .value?'
}
