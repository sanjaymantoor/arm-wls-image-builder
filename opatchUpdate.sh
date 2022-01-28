#!/bin/bash
# This script updates the opatch 

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./opatchUpdate.sh <<< <parameters>"
}

#Check the execution success
function checkSuccess()
{
	retValue=$1
	message=$2
	if [[ $retValue != 0 ]]; then
		echo_stderr "${message}"
		exit $retValue
	fi
}

#Function to cleanup all temporary files
function cleanup()
{
    echo "Cleaning up temporary files..."
    sudo rm -rf ${opatchWork}
}

function downloadUsingWget()
{
	sudo mkdir -p ${opatchWork}
	filename=${downloadURL##*/}
	for in in {1..5}
	do
		cd ${opatchWork}
		wget $downloadURL
		if [ $? != 0 ];
     	then
        	echo "${filename} patch download failed with $downloadURL. Trying again..."
			sudo rm -f $filename
     	else 
        	echo "${filename} patch Downloaded successfully"
        break
     fi
   done
   echo "Verifying the ${filename} patch download"
   ls  $filename
   checkSuccess $? "Error : Downloading ${filename} patch failed"
   
}

function updatePatch()
{
	cd ${opatchWork}
	echo "Opatch version before updating patch"
	runuser -l oracle -c "$oracleHome/OPatch/opatch version"
	filename=${downloadURL##*/}
   	unzip $filename
   	opatchFileName=`find . -name opatch_generic.jar`
	command="java -jar ${opatchFileName} -silent oracle_home=$oracleHome"
	sudo chown -R $username:$groupname ${opatchWork}
	echo "Executing optach update command:"${command}
	runuser -l oracle -c "cd $oracleHome/wlserver/server/bin ; . ./setWLSEnv.sh ;cd ${opatchWork}; ${command}"
	checkSuccess $? "Error : Updating opatch failed"
	echo "Opatch version after updating patch"
	runuser -l oracle -c "$oracleHome/OPatch/opatch version"
}

#main script starts here

read downloadURL

BASE_DIR="$(readlink -f ${CURR_DIR})"
CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
oracleHome="/u01/app/wls/install/oracle/middleware/oracle_home"
opatchWork="/u01/app/opatch"
groupname="oracle"
username="oracle"

if [ $downloadURL != "none" ];
then
	echo "================================================================="
	echo "##########         Starting OPatch patch update        ##########"
	echo "================================================================="
	
	downloadUsingWget
	updatePatch
	cleanup
	
	echo "================================================================="
	echo "##########         OPatch patch update completed        ##########"
	echo "================================================================="

fi	
  
