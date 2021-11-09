#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
#
# The OpenSearch Contributors require contributions made to
# this file be licensed under the Apache-2.0 license or a
# compatible open source license.

# This script is used to generate pkgs by using fpm

set -e

# Load libs
. ../../lib/shell/file_management.sh

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
    echo -e "-i INPUT_ARTIFACT\tSpecify \$PRODUCT tarball artifact, as the script will extract it and put files in corresponding folder."
    echo -e "-d DESCRIPTION\tSpecify the package description, e.g. Open source distributed and RESTful search engine."
    echo ""
    echo "Optional arguments:"
    echo -e "-h\t\tPrint this message."
    echo "--------------------------------------------------------------------------"
}

while getopts ":hv:t:p:a:i:d:" arg; do
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
        i)
            INPUT_ARTIFACT=$OPTARG
            ;;
        d)
            DESCRIPTION=$OPTARG
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
if [ -z "$VERSION" ] || [ -z "$TYPE" ] || [ -z "$PRODUCT" ] || [ -z "$ARCHITECTURE" ] || [ -z "$INPUT_ARTIFACT" ] || [ -z "$DESCRIPTION" ]
then
    echo "You must specify '-v VERSION', '-t TYPE', '-p PRODUCT', '-a APRODUCTRCHITECTURE', '-i INPUT_ARTIFACT', '-d DESCRIPTION'"
    exit 1
else
    echo $VERSION $TYPE $PRODUCT $ARCHITECTURE $INPUT_ARTIFACT $DESCRIPTION
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
DIR=`Temp_Folder_Create`
Trap_File_Delete_No_Sigchld $DIR
echo Create Work Directory: $DIR
echo Extract $INPUT_ARTIFACT
tar -xzf $INPUT_ARTIFACT --strip-components 1 --directory $DIR/
ls -l $DIR

fpm --force \
    --input-type dir \
    --output-type $TYPE \
    #--package $TARGET_DIR/NAME-$OD_VERSION.TYPE \
    --name $PRODUCT \
    --description "$DESCRIPTION" \
    --version $VERSION \
    --url https://opensearch.org/ \
    --vendor "OpenSearch" \
    --maintainer "OpenSearch" \
    --license "ASL 2.0" \
    --after-install $DIR/scripts/post_install.sh \
    --before-install $DIR/scripts/pre_install.sh \
    --before-remove $DIR/scripts/pre_remove.sh \
    --after-remove $DIR/scripts/post_remove.sh \
    --config-files /etc/$PRODUCT/$PRODUCT.yml \
    --template-value product=$PRODUCT \
    --template-value user=$PRODUCT \
    --template-value group=$PRODUCT \
    #--template-value optimizeDir=/usr/share/ \
    --template-value configDir=/etc/$PRODUCT \
    --template-value pluginsDir=/usr/share/$PRODUCT/plugins \
    --template-value dataDir=/usr/share/$PRODUCT/data \
    --exclude usr/share/$PRODUCT/config \
    --exclude usr/share/$PRODUCT/data \
    --architecture `eval echo '$'ARCHITECTURE_ALT_${type}` \
    --rpm-os linux \
    $DIR/=/usr/share/$PRODUCT/ \
    $DIR/config/=/etc/$PRODUCT/ \
    $DIR/data/=/usr/share/$PRODUCT/ \
    $DIR/service_templates/sysv/etc/=/etc/ \
    $DIR/service_templates/systemd/etc/=/etc/

