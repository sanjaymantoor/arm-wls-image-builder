#!/bin/bash

#Function to output message to StdErr
function echo_stderr ()
{
    echo "$@" >&2
}

#Function to display usage message
function usage()
{
  echo_stderr "./setupWLS.sh <<< <parameters>"
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

    rm -f $BASE_DIR/*.tar.gz
    rm -f $BASE_DIR/*.zip

    rm -rf $JDK_PATH/*.tar.gz
    rm -rf $WLS_PATH/*.zip

    rm -rf $WLS_PATH/silent-template

    rm -rf $WLS_JAR
    echo "Cleanup completed."
}

#download 3rd Party JDBC Drivers
function downloadJDBCDrivers()
{
   echo "Downloading JDBC Drivers..."

   echo "Downloading postgresql Driver..."
   downloadUsingWget ${POSTGRESQL_JDBC_DRIVER_URL}

   echo "Downloading mssql Driver"
   downloadUsingWget ${MSSQL_JDBC_DRIVER_URL}

   echo "JDBC Drivers Downloaded Completed Successfully."
}



function setupWDT()
{
    DIR_PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    echo "Creating domain path /u01/domains"
    echo "Downloading weblogic-deploy-tool"
    DOMAIN_PATH="/u01/domains" 
    sudo mkdir -p $DOMAIN_PATH 
    sudo rm -rf $DOMAIN_PATH/*

    cd $DOMAIN_PATH
    wget -q $WEBLOGIC_DEPLOY_TOOL
    checkSuccess $? "Error : Downloading weblogic-deploy-tool failed"
    sudo unzip -o weblogic-deploy.zip -d $DOMAIN_PATH
    sudo chown -R $username:$groupname $DOMAIN_PATH
    rm $DOMAIN_PATH/weblogic-deploy.zip
    cd $DIR_PWD

}


function downloadUsingWget()
{
   downloadURL=$1
   filename=${downloadURL##*/}
   for in in {1..5}
   do
     echo wget --no-check-certificate $downloadURL
     wget --no-check-certificate $downloadURL
     if [ $? != 0 ];
     then
        echo "$filename Driver Download failed on $downloadURL. Trying again..."
     rm -f $filename
     else 
        echo "$filename Driver Downloaded successfully"
        break
     fi
   done
   echo "Verifying the driver download"
   ls  $filename
   checkSuccess $? "Error : Downloading driver ${filename} failed"
}

function copyJDBCDriversToWeblogicClassPath()
{
     echo "Copying JDBC Drivers to Weblogic CLASSPATH ..."
     sudo cp $BASE_DIR/${POSTGRESQL_JDBC_DRIVER} ${WL_HOME}/server/lib/
     sudo cp $BASE_DIR/${MSSQL_JDBC_DRIVER} ${WL_HOME}/server/lib/

     chown $username:$groupname ${WL_HOME}/server/lib/${POSTGRESQL_JDBC_DRIVER}
     chown $username:$groupname ${WL_HOME}/server/lib/${MSSQL_JDBC_DRIVER}

     echo "Copied JDBC Drivers to Weblogic CLASSPATH"
     ls ${WL_HOME}/server/lib/${POSTGRESQL_JDBC_DRIVER}
     checkSuccess $? "Error : Copying ${POSTGRESQL_JDBC_DRIVER} to ${WL_HOME}/server/lib failed"  
     ls ${WL_HOME}/server/lib/${MSSQL_JDBC_DRIVER}
     checkSuccess $? "Error : Copying ${MSSQL_JDBC_DRIVER} to ${WL_HOME}/server/lib failed"   
}

function modifyWLSClasspath()
{
  echo "Modify WLS CLASSPATH ...."
  sed -i 's;^WEBLOGIC_CLASSPATH=\"${JAVA_HOME}.*;&\nWEBLOGIC_CLASSPATH="${WL_HOME}/server/lib/postgresql-42.2.8.jar:${WL_HOME}/server/lib/mssql-jdbc-7.4.1.jre8.jar:${WEBLOGIC_CLASSPATH}";' ${WL_HOME}/../oracle_common/common/bin/commExtEnv.sh
  sed -i 's;^WEBLOGIC_CLASSPATH=\"${JAVA_HOME}.*;&\n\n#**WLSAZURECUSTOMSCRIPTEXTENSION** Including Postgresql and MSSSQL JDBC Drivers in Weblogic Classpath;' ${WL_HOME}/../oracle_common/common/bin/commExtEnv.sh
  echo "Modified WLS CLASSPATH."
}


#Function to create Weblogic Installation Location Template File for Silent Installation
function create_oraInstlocTemplate()
{
    echo "creating Install Location Template..."

    cat <<EOF >$WLS_PATH/silent-template/oraInst.loc.template
inventory_loc=[INSTALL_PATH]
inst_group=[GROUP]
EOF
}

#Function to create Weblogic Installation Response Template File for Silent Installation
function create_oraResponseTemplate()
{

    echo "creating Response Template..."

    cat <<EOF >$WLS_PATH/silent-template/response.template
[ENGINE]

#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]

#Set this to true if you wish to skip software updates
DECLINE_AUTO_UPDATES=false

#My Oracle Support User Name
MOS_USERNAME=

#My Oracle Support Password
MOS_PASSWORD=<SECURE VALUE>

#If the Software updates are already downloaded and available on your local system, then specify the path to the directory where these patches are available and set SPECIFY_DOWNLOAD_LOCATION to true
AUTO_UPDATES_LOCATION=

#Proxy Server Name to connect to My Oracle Support
SOFTWARE_UPDATES_PROXY_SERVER=

#Proxy Server Port
SOFTWARE_UPDATES_PROXY_PORT=

#Proxy Server Username
SOFTWARE_UPDATES_PROXY_USER=

#Proxy Server Password
SOFTWARE_UPDATES_PROXY_PASSWORD=<SECURE VALUE>

#The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=[INSTALL_PATH]/oracle/middleware/oracle_home

#Set this variable value to the Installation Type selected. e.g. WebLogic Server, Coherence, Complete with Examples.
INSTALL_TYPE=WebLogic Server

#Provide the My Oracle Support Username. If you wish to ignore Oracle Configuration Manager configuration provide empty string for user name.
MYORACLESUPPORT_USERNAME=

#Provide the My Oracle Support Password
MYORACLESUPPORT_PASSWORD=<SECURE VALUE>

#Set this to true if you wish to decline the security updates. Setting this to true and providing empty string for My Oracle Support username will ignore the Oracle Configuration Manager configuration
DECLINE_SECURITY_UPDATES=true

#Set this to true if My Oracle Support Password is specified
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false

#Provide the Proxy Host
PROXY_HOST=

#Provide the Proxy Port
PROXY_PORT=

#Provide the Proxy Username
PROXY_USER=

#Provide the Proxy Password
PROXY_PWD=<SECURE VALUE>

#Type String (URL format) Indicates the OCM Repeater URL which should be of the format [scheme[Http/Https]]://[repeater host]:[repeater port]
COLLECTOR_SUPPORTHUB_URL=


EOF
}

#Function to create Weblogic Uninstallation Response Template File for Silent Uninstallation
function create_oraUninstallResponseTemplate()
{
    echo "creating Uninstall Response Template..."

    cat <<EOF >$WLS_PATH/silent-template/uninstall-response.template
[ENGINE]

#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]

#This will be blank when there is nothing to be de-installed in distribution level
SELECTED_DISTRIBUTION=WebLogic Server~[WLSVER]

#The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=[INSTALL_PATH]/oracle/middleware/oracle_home/

EOF
}

#Install Weblogic Server using Silent Installation Templates
function installWLS()
{
    # Using silent file templates create silent installation required files
    echo "Creating silent files for installation from silent file templates..."

    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/uninstall-response.template > ${SILENT_FILES_DIR}/uninstall-response
    sed -i 's@\[WLSVER\]@'"$WLS_VER"'@' ${SILENT_FILES_DIR}/uninstall-response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/response.template > ${SILENT_FILES_DIR}/response
    sed 's@\[INSTALL_PATH\]@'"$INSTALL_PATH"'@' ${SILENT_FILES_DIR}/oraInst.loc.template > ${SILENT_FILES_DIR}/oraInst.loc
    sed -i 's@\[GROUP\]@'"$USER_GROUP"'@' ${SILENT_FILES_DIR}/oraInst.loc

    echo "Created files required for silent installation at $SILENT_FILES_DIR"

    export UNINSTALL_SCRIPT=$INSTALL_PATH/oracle/middleware/oracle_home/oui/bin/deinstall.sh
    if [ -f "$UNINSTALL_SCRIPT" ]
    then
            currentVer=`. $INSTALL_PATH/oracle/middleware/oracle_home/wlserver/server/bin/setWLSEnv.sh 1>&2 ; java weblogic.version |head -2`
            echo "#########################################################################################################"
            echo "Uninstalling already installed version :"$currentVer
            runuser -l oracle -c "$UNINSTALL_SCRIPT -silent -responseFile ${SILENT_FILES_DIR}/uninstall-response"
            sudo rm -rf $INSTALL_PATH/*
            echo "#########################################################################################################"
    fi

    echo "---------------- Installing WLS ${WLS_JAR} ----------------"
    
    
    if [[ "$jdkversion" =~ ^jdk1.8* ]]
    then
    
    echo $JAVA_HOME/bin/java -d64  -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation
    runuser -l oracle -c "$JAVA_HOME/bin/java -d64 -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation"
    
    else 

    echo $JAVA_HOME/bin/java -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation
    runuser -l oracle -c "$JAVA_HOME/bin/java -jar  ${WLS_JAR} -silent -invPtrLoc ${SILENT_FILES_DIR}/oraInst.loc -responseFile ${SILENT_FILES_DIR}/response -novalidation"
    
    fi

    # Check for successful installation and version requested
    if [[ $? == 0 ]];
    then
      echo "Weblogic Server Installation is successful"
    else

      echo_stderr "Installation is not successful"
      exit 1
    fi
    echo "#########################################################################################################"

}


#main script starts here

CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BASE_DIR="$(readlink -f ${CURR_DIR})"


read shiphomeurl jdkurl wlsversion jdkversion

if [ -z "$shiphomeurl" ];
then
        echo_stderr "wls shiphome url is required. "
        exit 1		
fi

if [ -z "$jdkurl" ];
then
        echo_stderr "jdk url is required. "
        exit 1		
fi

if [ -z "$wlsversion" ];
then
        echo_stderr "wlsversion is required. "
        exit 1		
fi

if [ -z "$jdkversion" ];
then
        echo_stderr "jdkversion is required. "
        exit 1		
fi

export WLS_VER=$wlsversion
export WEBLOGIC_DEPLOY_TOOL=https://github.com/oracle/weblogic-deploy-tooling/releases/download/weblogic-deploy-tooling-1.8.1/weblogic-deploy.zip
export POSTGRESQL_JDBC_DRIVER_URL=https://jdbc.postgresql.org/download/postgresql-42.2.8.jar 
export POSTGRESQL_JDBC_DRIVER=${POSTGRESQL_JDBC_DRIVER_URL##*/}

export MSSQL_JDBC_DRIVER_URL=https://repo.maven.apache.org/maven2/com/microsoft/sqlserver/mssql-jdbc/7.4.1.jre8/mssql-jdbc-7.4.1.jre8.jar
export MSSQL_JDBC_DRIVER=${MSSQL_JDBC_DRIVER_URL##*/}

# This has to be done first as wget is not available with Oracle Linux 7.3
echo "Installing zip unzip wget vnc-server rng-tools cifs-utils"
sudo yum install -y zip unzip wget vnc-server rng-tools cifs-utils

echo "================================================================="
echo "##########           Starting WebLogic setup           ##########" 
echo "================================================================="

#add oracle group and user
echo "Adding oracle user and group..."
groupname="oracle"
username="oracle"
user_home_dir="/u01/oracle"
USER_GROUP=${groupname}
sudo groupadd $groupname
sudo useradd -d ${user_home_dir} -g $groupname $username


JDK_PATH="/u01/app/jdk"
WLS_PATH="/u01/app/wls"
WL_HOME="/u01/app/wls/install/oracle/middleware/oracle_home/wlserver"


#create custom directory for setting up wls and jdk
sudo mkdir -p $JDK_PATH
sudo mkdir -p $WLS_PATH
sudo rm -rf $JDK_PATH/*
sudo rm -rf $WLS_PATH/*


#download jdk from OTN
echo "Downloading jdk"
#curl -s https://raw.githubusercontent.com/typekpb/oradown/master/oradown.sh  | bash -s -- --cookie=accept-weblogicserver-server --username="${otnusername}" --password="${otnpassword}" $jdkurl
wget -q --progress=dot --no-check-certificate $jdkurl

#Download Weblogic install jar from OTN
echo "Downloading weblogic install kit"
#curl -s https://raw.githubusercontent.com/typekpb/oradown/master/oradown.sh  | bash -s -- --cookie=accept-weblogicserver-server --username="${otnusername}" --password="${otnpassword}" $shiphomeurl
wget -q --progress=dot --no-check-certificate $shiphomeurl  

#download Weblogic deploy tool 

sudo chown -R $username:$groupname /u01/app


sudo cp $BASE_DIR/fmw_*.zip $WLS_PATH/
sudo cp $BASE_DIR/jdk-*.tar.gz $JDK_PATH/

echo "extracting and setting up jdk..."
sudo tar -zxvf $JDK_PATH/jdk-*.tar.gz --directory $JDK_PATH
sudo chown -R $username:$groupname $JDK_PATH

export JAVA_HOME=$JDK_PATH/$jdkversion
export PATH=$JAVA_HOME/bin:$PATH

echo "JAVA_HOME set to $JAVA_HOME"
echo "PATH set to $PATH"

java -version

if [ $? == 0 ];
then
    echo "JAVA HOME set succesfully."
else
    echo_stderr "Failed to set JAVA_HOME. Please check logs and re-run the setup"
    exit 1
fi

#Setting up rngd utils
sudo systemctl enable rngd 
sudo systemctl status rngd
sudo systemctl start rngd
sudo systemctl status rngd

echo "unzipping wls install archive..."
sudo unzip -o $WLS_PATH/fmw_*.zip -d $WLS_PATH

export SILENT_FILES_DIR=$WLS_PATH/silent-template
sudo mkdir -p $SILENT_FILES_DIR
sudo rm -rf $WLS_PATH/silent-template/*
sudo chown -R $username:$groupname $WLS_PATH

export INSTALL_PATH="$WLS_PATH/install"
export WLS_JAR=$WLS_PATH"/fmw_"$wlsversion"_wls.jar"

mkdir -p $INSTALL_PATH
sudo chown -R $username:$groupname $INSTALL_PATH

create_oraInstlocTemplate
create_oraResponseTemplate
create_oraUninstallResponseTemplate

installWLS

setupWDT

downloadJDBCDrivers

copyJDBCDriversToWeblogicClassPath

modifyWLSClasspath

cleanup

echo "================================================================="
echo "##########           WebLogic setup completed          ##########"
echo "================================================================="


# FOLLOWING IS COMMENTED AS REBOOT IS NOT WORKING FOR IMAGE BUILDER

#echo "================================================================="
#echo "##########           Update software to latest         ##########" 
#echo "=================================================================" 
#osVersion=`cat /etc/os-release | grep VERSION_ID |cut -f2 -d"="| sed 's/\"//g'`
#majorVersion=`echo $osVersion |cut -f1 -d"."`
#minorVersion=`echo $osVersion |cut -f2 -d"."`

#echo "Kernel version before update:"
#uname -a

#echo yum upgrade -y --disablerepo=ol7_latest  --enablerepo=ol${majorVersion}_u${minorVersion}_base
#yum upgrade -y --disablerepo=ol7_latest  --enablerepo=ol${majorVersion}_u${minorVersion}_base

#echo "Kernel version after update:"
#uname -a

#echo "================================================================="
#echo "##########           Update software completed         ##########"
#echo "=================================================================" 



