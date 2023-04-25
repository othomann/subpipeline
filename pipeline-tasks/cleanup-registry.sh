#!/usr/bin/env bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2018. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################

# Walk the images named $IMAGE_NAME in namespace $REGISTRY_NAMESPACE in reverse chronological order,
# keep the $KEEP_IMAGES most recent images starting with the image tagged $FROM_TAG,
# and delete the older ones

# Ensure REGISTRY_NAMESPACE and IMAGE_NAME are set
if [ -z "$REGISTRY_NAMESPACE" ]; then
    echo "Missing one of: REGISTRY_NAMESPACE"
    echo "Usage:"
    echo "export REGISTRY_NAMESPACE=opentoolchain"
    echo ". cleanup_images.sh [-delete]"
    exit 1
fi

# Default number of images to keep: 5
if [ -z "$TIMESTAMP" ]; then
    TIMESTAMP=$(date  --date="367 days ago" +"%s")
fi

echo "Deleting images for namespace ${REGISTRY_NAMESPACE}, keep all images older than $(date -d @TIMESTAMP)"

if [ "$1" != "-delete" ]; then
    echo "-delete flag not set, this will simulate the deletion"
fi

# Get images for component and sort them most recent first
LIST=$(bx cr images --restrict ${REGISTRY_NAMESPACE}/${IMAGE_NAME} --no-trunc --format '{{ .Created }} {{ .Repository }} {{ .Tag }} {{ .Digest }}' | sort -r -u)
echo " "
echo "List of images for ${REGISTRY_NAMESPACE}/${IMAGE_NAME}"
echo "$LIST"

# First pass to get $FROM_TAG digest
while read line
do
    TAG=$(echo $line | awk '{print $3};')
    if [[ "${TAG}" != "${FROM_TAG}" ]]; then continue; fi
    FROM_TAG_DIGEST=$(echo $line | awk '{print $4};')
    break;
done <<< "$LIST"

#echo " "
#echo "######### Debugging #############"
#echo REGISTRY_NAMESPACE:$REGISTRY_NAMESPACE
#echo IMAGE_NAME:$IMAGE_NAME
#echo KEEP_IMAGES:$KEEP_IMAGES
#echo FROM_TAG:$FROM_TAG
#echo FROM_TAG_DIGEST:$FROM_TAG_DIGEST
#echo "######### End debugging #########"

# Delete images that are older than $FROM_TAG, but keeping the $KEEP_IMAGES more recent ones
echo " "
echo "Processing images..."
COUNT=-1
while read line
do
    TAG=$(echo $line | awk '{print $3};')
    if [[ "${TAG}" == "" ]]; then continue; fi
    if [[ "${TAG}" == "TAG" ]]; then continue; fi
    if [[ "${TAG}" == "${FROM_TAG}" ]]; then 
        COUNT=$KEEP_IMAGES
    fi
    DIGEST=$(echo $line | awk '{print $4};')
    REPOSITORY=$(echo $line | awk '{print $2};')
    if [[ "$COUNT" -eq "-1" ]]; then # have not reached the $FROM_TAG image yet
        echo "Keeping image $REPOSITORY:$TAG $DIGEST"
        continue;
    fi
    if [[ "$TAG" == "$FROM_TAG" ]]; then
        echo "Keeping image $REPOSITORY:$TAG $DIGEST"
        COUNT=$((COUNT-1)) 
        continue;
    fi
    if [[ "$DIGEST" == "$FROM_TAG_DIGEST" ]]; then # image tagged twice
        echo "Keeping image $REPOSITORY:$TAG $DIGEST"
        continue;
    fi
    if [[ "$COUNT" -gt "0" ]]; then
        echo "Keeping image $REPOSITORY:$TAG $DIGEST"
        COUNT=$((COUNT-1)) 
        continue;
    fi
    if [ "$1" != "-delete" ]; then
        echo "(simulate) bx cr image-rm $REPOSITORY:$TAG"
    else
        bx cr image-rm $REPOSITORY:$TAG
    fi
done <<< "$LIST"