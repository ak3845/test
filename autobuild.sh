#!/bin/sh

# Test AutoBuild control file
# Matthew Booth - 04/01/2007

set -x

. build/build.properties
release=`build/svnrevision.sh .`

nvr=${name}-${version}-${release}
rpm=${nvr}.noarch.rpm
srpm=${nvr}.src.rpm

nvr_tr=${name}-test-results-${version}-${release}
rpm_tr=${nvr_tr}.noarch.rpm

# Clean out the source directory from any previous run
ant -f build/build.xml clean

ant -f build/build.xml \
    -Drpmdir=$AUTOBUILD_PACKAGE_ROOT/rpm \
    -Dbuild.number=$release srpm
retval=$?
[ $retval -ne 0 ] && exit $retval

if [ ! -z "$MOCK_ENV" ]; then
    mock_root=/var/lib/mock/$MOCK_ENV
    mock_result_root=$mock_root/result
    mock_build_root=$mock_root/root/builddir/build/BUILD/${name}-${version}

    mock --arch=noarch --autocache -r $MOCK_ENV dist/$srpm
    retval=$?

    mv $mock_result_root/{${rpm},${rpm_tr}} \
       $AUTOBUILD_PACKAGE_ROOT/rpm/RPMS/noarch/

    # Extract the test results from the test-results rpm into the location they
    # would have ended up in if we'd done a regular rpmbuild
    mkdir -p junit/reports
    mkdir -p junit/junit-logs
    mkdir -p docs

    # The build root is cleaned after a successful build, so extract files from
    # rpm
    if [ -f $AUTOBUILD_PACKAGE_ROOT/rpm/RPMS/noarch/${rpm_tr} ]; then
        pushd junit/reports
        rpm2cpio $AUTOBUILD_PACKAGE_ROOT/rpm/RPMS/noarch/${rpm_tr} | cpio -id
        mv opt/vodafone/${name}-${version}/test-results/* .
        rm -rf opt
        popd

        pushd docs
        rpm2cpio $AUTOBUILD_PACKAGE_ROOT/rpm/RPMS/noarch/${rpm_tr} | cpio -id
        mv opt/vodafone/${name}-${version}/docs/* .
        rm -rf opt
        popd

        pushd junit/junit-logs
        rpm2cpio $AUTOBUILD_PACKAGE_ROOT/rpm/RPMS/noarch/${rpm_tr} | cpio -id
        mv opt/vodafone/${name}-${version}/test-logs/* .
        rm -rf opt
        popd
        
    # Otherwise pull the files directly out of the build root
    else
        cp -r $mock_build_root/junit/reports/* junit/reports
        cp -r $mock_build_root/test-results/* junit/junit-logs
        cp -r $mock_build_root/docs/* docs
    fi

    echo '*********************************************************************'
    echo inm root.log
    echo '*********************************************************************'
    cat $mock_result_root/root.log
    echo
    echo '*********************************************************************'
    echo inm build.log
    echo '*********************************************************************'
    cat $mock_result_root/build.log
else
    rpmbuild --rebuild --define "_topdir $AUTOBUILD_PACKAGE_ROOT/rpm" dist/$srpm
    retval=$?
fi

exit $retval
