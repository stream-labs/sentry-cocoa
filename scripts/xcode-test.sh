#!/bin/bash
set -uox pipefail

# This is a helper script for GitHub Actions Matrix.
# If we would specify the destinations in the GitHub Actions
# Matrix, the name of the job would include the destination, which would
# be, for example, platform=tvOS Simulator,OS=latest,name=Apple TV 4K.
# To fix this, we specify a readable platform in the matrix and then call
# this script to map the platform to the destination.

PLATFORM="${1}"
OS=${2:-latest}
REF_NAME="${3-HEAD}"
IS_LOCAL_BUILD="${4:-ci}"
COMMAND="${5:-test}"
DESTINATION=""
CONFIGURATION=""

case $PLATFORM in

    "macOS")
        DESTINATION="platform=macOS"
        ;;

    "Catalyst")
        DESTINATION="platform=macOS,variant=Mac Catalyst"
        ;;

    "iOS")
        DESTINATION="platform=iOS Simulator,OS=$OS,name=iPhone 8"
        ;;

    "tvOS")
        DESTINATION="platform=tvOS Simulator,OS=$OS,name=Apple TV"
        ;;

    *)
        echo "Xcode Test: Can't find destination for platform '$PLATFORM'";
        exit 1;
        ;;
esac

case $REF_NAME in
    "main")
        CONFIGURATION="TestCI"
        ;;
    
    *)
        CONFIGURATION="Test"
        ;;
esac

case $IS_LOCAL_BUILD in
    "ci")
        RUBY_ENV_ARGS=""
        ;;
    *)
        RUBY_ENV_ARGS="rbenv exec bundle exec"
        ;;
esac

case $COMMAND in
    "build-for-testing")
        RUN_BUILD_FOR_TESTING=true
        RUN_TEST_WITHOUT_BUILDING=false
        ;;
    "test-without-building")
        RUN_BUILD_FOR_TESTING=false
        RUN_TEST_WITHOUT_BUILDING=true
        ;;
    *)
        RUN_BUILD_FOR_TESTING=true
        RUN_TEST_WITHOUT_BUILDING=true
        ;;
esac

if [ $RUN_BUILD_FOR_TESTING == true ]; then
    # build everything for testing
    env NSUnbufferedIO=YES xcodebuild       \
        -workspace Sentry.xcworkspace       \
        -scheme Sentry                      \
        -configuration $CONFIGURATION       \
        -destination "$DESTINATION" -quiet  \
        build-for-testing
fi

if [ $RUN_TEST_WITHOUT_BUILDING == true ]; then
    # run the tests
    env NSUnbufferedIO=YES xcodebuild                               \
        -workspace Sentry.xcworkspace                               \
        -scheme Sentry                                              \
        -configuration $CONFIGURATION                               \
        -destination "$DESTINATION"                                 \
        test-without-building                                       \
            | tee raw-test-output.log                               \
            | $RUBY_ENV_ARGS xcpretty -t                            \
                && slather coverage --configuration $CONFIGURATION  \
                && exit ${PIPESTATUS[0]}
fi
