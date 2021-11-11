#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# This script is used to generate pkgs by using fpm
# It does not run by itself and required to be executed by `./assemble.sh <builds manifest file> --distribution deb/rpm`
# As of now it only supports building packages correctly on LINUX host for deb/rpm.

set -e

# Setup root
ROOT=`dirname $(realpath $0)`; echo $ROOT; cd $ROOT

function usage() {
    echo ""
    echo "This script is used to build the OpenSearch related packages."
    echo "--------------------------------------------------------------------------"
    echo "Usage: $0 [args]"
    echo ""
    echo "Required arguments:"
    echo -e "-v VERSION\tSpecify the package version number, e.g. 1.1.0"
    echo -e "-t TYPE\tSpecify the package type, e.g. rpm/deb/pkg."
    echo -e "-p PRODUCT\tSpecify the package product, e.g. opensearch / opensearch_dashboards, etc."
    echo -e "-a ARCHITECTURE\tSpecify the package architecture, e.g. x64 or arm64."
    echo -e "-d DIRECTORY\tSpecify directory of the content that fpm can use to pack into a pkg."
    echo ""
    echo "Optional arguments:"
    echo -e "-h\t\tPrint this message."
    echo "--------------------------------------------------------------------------"
}

while getopts ":hv:t:p:a:d:" arg; do
    case $arg in
        h)
            usage
            exit 1
            ;;
        v)
            VERSION=$OPTARG
            ;;
        t)
            TYPE=$OPTARG
            ;;
        p)
            PRODUCT=$OPTARG
            ;;
        a)
            ARCHITECTURE=$OPTARG
            ;;
        d)
            DIRECTORY=$OPTARG
            ;;
        :)
            echo "-${OPTARG} requires an argument"
            usage
            exit 1
            ;;
        ?)
            echo "Invalid option: -${arg}"
            exit 1
            ;;
    esac
done

# Check parameters
if [ -z "$VERSION" ] || [ -z "$TYPE" ] || [ -z "$PRODUCT" ] || [ -z "$ARCHITECTURE" ] || [ -z "$DIRECTORY" ]
then
    echo "You must specify '-v VERSION', '-t TYPE', '-p PRODUCT', '-a APRODUCTRCHITECTURE', '-d DIRECTORY'"
    exit 1
else
    echo $VERSION $TYPE $PRODUCT $ARCHITECTURE $DIRECTORY
fi

# Check architecture
if [ "$ARCHITECTURE" = "x64" ]
then
    ARCHITECTURE_ALT_rpm="x86_64"
    ARCHITECTURE_ALT_deb="amd64"
elif [ "$ARCHITECTURE" = "arm64" ]
then
    ARCHITECTURE_ALT_rpm="aarch64"
    ARCHITECTURE_ALT_deb="arm64"
else
    echo "User enter wrong architecture, choose among x64/arm64"
    exit 1
fi

# Check product
if [ "$PRODUCT" != "opensearch" ] && [ "$PRODUCT" != "opensearch_dashboards" ]
then
    echo "User enter wrong product, choose among opensearch/opensearch_dashboards"
    exit 1
fi

# Setup cleanups
DIR=`realpath $DIRECTORY`
echo "List content in $DIR for $PRODUCT $VERSION"
mkdir -p $DIR/data
ls -l $DIR
ARCHITECTURE_FINAL=`eval echo '$'ARCHITECTURE_ALT_${TYPE}`

fpm --force \
    --verbose \
    --input-type dir \
    --package $ROOT/NAME-$VERSION.TYPE \
    --output-type $TYPE \
    --name $PRODUCT \
    --description "$PRODUCT $TYPE $VERSION" \
    --version $VERSION \
    --url https://opensearch.org/ \
    --vendor "OpenSearch" \
    --maintainer "OpenSearch" \
    --license "ASL 2.0" \
    --after-install $ROOT/scripts/post_install.sh \
    --before-install $ROOT/scripts/pre_install.sh \
    --before-remove $ROOT/scripts/pre_remove.sh \
    --after-remove $ROOT/scripts/post_remove.sh \
    --config-files /etc/$PRODUCT/$PRODUCT.yml \
    --template-value product=$PRODUCT \
    --template-value user=$PRODUCT \
    --template-value group=$PRODUCT \
    --template-value configDir=/etc/$PRODUCT \
    --template-value pluginsDir=/usr/share/$PRODUCT/plugins \
    --template-value dataDir=/usr/share/$PRODUCT/data \
    --exclude usr/share/$PRODUCT/config \
    --architecture $ARCHITECTURE_FINAL \
    $DIR/=/usr/share/$PRODUCT/ \
    $DIR/config/=/etc/$PRODUCT/ \
    $DIR/data/=/usr/share/$PRODUCT/ \
    $ROOT/service_templates/systemd/etc/=/etc/
