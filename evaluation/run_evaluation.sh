#!/bin/bash

NUM_SCENARIOS=5
NUM_RUNS=5

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
WORKDIR=$DIR/../target

function COPY_CONFIG() {
    cat $DIR/config/config_common.txt > $DIR/../Challenge\ problem/Settings/config.txt
    echo "" >> $DIR/../Challenge\ problem/Settings/config.txt
    cat $DIR/config/config_$1.txt >> $DIR/../Challenge\ problem/Settings/config.txt
}

function SIMULATOR_EXEC() {
    $DIR/../Challenge\ problem/Windows/Challenge-Win64.exe -batchmode &> /dev/null &
    sleep 1
}
function OBSERVER_EXEC() {
    pushd $DIR/../Challenge\ problem/ > /dev/null
    java -jar UnityObserver.jar &> $1 &
    sleep 1
    popd > /dev/null
}

function GO_EXEC() {
    pushd $DIR/../ > /dev/null
    $DIR/../thingml-gen/go/RoverControllerGo/RoverControllerGo.exe &> $1 &
    popd > /dev/null
}

function JAVA_EXEC() {
    pushd $DIR/../ > /dev/null
    java -jar $DIR/../thingml-gen/java/RoverControllerJava/target/RoverControllerJava-1.0.0-jar-with-dependencies.jar &> $1 &
    popd > /dev/null
}

function RUN_TO_COMPLETION() {
    # Start simulator
    SIMULATOR_EXEC
    SIMULATOR_PID=$!
    # Start observer
    OBSERVER_EXEC $2
    OBSERVER_PID=$!
    # Start controller
    $1_EXEC $3
    CONTROLLER_PID=$!

    # Wait for observer to finish
    wait $OBSERVER_PID
    kill -9 $CONTROLLER_PID &> /dev/null
    kill -9 $SIMULATOR_PID &> /dev/null
}

# Clean target directory
rm -rf $WORKDIR/*

for i in `seq 1 $NUM_SCENARIOS`; do
    # Create directory for this scenario
    DIR_SCENARIO=$WORKDIR/Scenario$i
    mkdir -p $DIR_SCENARIO

    # Generate the trajectory and record it
    echo "Generating recorded trajectory for Scenario $i"
    COPY_CONFIG generate_new
    RUN_TO_COMPLETION GO /dev/null /dev/null
    COPY_CONFIG prerecorded

    # Copy the recorded trajectory
    cp "$DIR/../Challenge problem/savedReplay.csv" $DIR_SCENARIO/replay.csv

    # Run multiple times
    for j in `seq 1 $NUM_RUNS`; do
        DIR_RUN=$DIR_SCENARIO/Run$j
        mkdir $DIR_RUN

        echo "Running GO for Scenario $i - Run $j"
        RUN_TO_COMPLETION GO $DIR_RUN/go_observer.log $DIR_RUN/go_controller.log

        echo "Running JAVA for Scenario $i - Run $j"
        RUN_TO_COMPLETION JAVA $DIR_RUN/java_observer.log $DIR_RUN/java_controller.log
    done
done