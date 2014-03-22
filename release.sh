#!/bin/bash
# Use this script to release a new version of pynag


# Extract current version information
current_version=$(grep ^Version: pynag.spec | awk '{ print $2 }')
current_release=$(grep "define release" pynag.spec | awk '{ print $3 }')

UPDATE_INFO_FILE=$(mktemp)
freecode_file=$(mktemp)
trap "rm -f ${UPDATE_INFO_FILE} ${freecode_file}" EXIT

if [ -z "$EDITOR" ]; then
    EDITOR=vi
fi

if [ -z $BASH ]; then
    echo "You need /bin/bash to run this script"
    exit 1
fi

main() {
    enter_release_info || echo FAIL

    update_changes || echo FAI

    update_version_number || echo FAIL

    git_commit || echo FAIL

    git_push || echo FAIL

    upload_to_pypi || echo FAIL

    upload_to_freecode || echo FAIL

    echo "### All Done"
}



update_changes() {
    ask "Update Changelog?" || return 0
    ${EDITOR} CHANGES || return 1
}


upload_to_pypi() {
    ask "Upload to pypi?" || return 0
    python setup.py build sdist upload || return 1
}

git_push() {
    ask "Upload to github?" || return 0
    git push origin master || return 1
    git push --tags origin master || return 1
}


upload_to_freecode() {
    ask "Upload to freecode?" || return 0
    error=0
    which freecode-submit &> /dev/null || error=1
    grep freecode ~/.netrc &> /dev/null || error=1

    if [ $error -gt 0 ]; then
        echo freecode-submit missing, please install and update .netrc appropriately
        echo
        echo use yum install freecode-submit or equivilent for your distribution
        echo
        echo Next you have to find your API key on freecode.com and put it into ~/.netrc
        echo
        echo 'echo "machine freecode account <apikey> password none" >> ~/.netrc'
        return 1
    fi

    echo "Project: pynag" > ${freecode_file}
    echo "Version: ${new_version}" >> ${freecode_file}
    echo "Hide: N" >> ${freecode_file}
    echo "Website-URL: http://pynag.org/" >> ${freecode_file}
    echo "Tar/GZ-URL: https://pypi.python.org/packages/source/p/pynag/pynag-${new_version}.tar.gz" >> ${freecode_file}

    grep -A24 '^$' ${UPDATE_INFO_FILE} >> ${freecode_file}
    freecode-submit < ${freecode_file}

}



enter_release_info() {
    echo "Current version is: $current_version" > ${UPDATE_INFO_FILE}
    echo "New version number: " >> ${UPDATE_INFO_FILE}
    echo 'Summary: <one line summary>' >> ${UPDATE_INFO_FILE}
    echo '' >> ${UPDATE_INFO_FILE}
    echo '<full description>' >> ${UPDATE_INFO_FILE}
    ${EDITOR} ${UPDATE_INFO_FILE}

    new_version=$(grep '^New version number:' ${UPDATE_INFO_FILE} | sed 's/^New version number: *//' | sed 's/ *$//')
    short_desc=$(grep '^Summary:' ${UPDATE_INFO_FILE} | sed 's/^Summary: *//')

    # Some sanity checking
    if [ -z "${new_version}" ]; then
        echo "New version is required"
        exit 1
    fi
    if [ -z "${short_desc}" ]; then
        echo "Summary is required"
        exit 1
    fi

}


update_version_number() {
    ask "Update version number?" || return 0
    echo
    echo "### Updating Makefile"
    sed -i "s/^VERSION.*= ${current_version}/VERSION		= ${new_version}/" Makefile
    echo "### Updating pynag/__init__.py"
    sed -i "s/^__version__ =.*/__version__ = '${new_version}'/" pynag/__init__.py
    echo "### Updating pynag.spec"
    sed -i "s/^Version: ${current_version}/Version: ${new_version}/" pynag.spec
    echo "### Updating rel-eng/packages/pynag"
    echo "${new_version}-${current_release} /" > rel-eng/packages/pynag

    echo "### Updating debian.upstream/changelog"
    update_debian_changelog

}

update_debian_changelog() {
    DATE=$(LANG=C date -R)
    NAME=$(git config --global --get user.name)
    MAIL=$(git config --global --get user.email)
    changelog=$(mktemp)
    echo "pynag (${new_version}-${current_release}) unstable; urgency=low" > ${changelog}
    echo "  " >> ${changelog}
    echo "  * New upstream version" >> ${changelog}
    echo "  " >> ${changelog}
    echo "  -- ${NAME} <${MAIL}>  ${DATE}" >> ${changelog}
    echo "" >> ${changelog}
    cat debian.upstream/changelog >> ${changelog}
    cp -f ${changelog} debian.upstream/changelog
}


git_commit() {
    ask "Commit changes to git and tag release ?" || return 0
    git commit Makefile pynag/__init__.py rel-eng/packages/pynag pynag.spec debian.upstream/changelog -m "Bumped version number to $new_version" > /dev/null
    git tag pynag-${new_version}-${current_release} -a -m "Bumped version number to $new_version"
}

ask() {
    read -n 1 -p "### $@ [Yn] "
    echo
    if [[ $REPLY =~ n ]]; then
        return 1
    else
        return 0
    fi
}

#main;

# vim: sts=4 expandtab autoindent
