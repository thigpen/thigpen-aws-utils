#!/bin/sh

################################################################################
#
# If a region is given as a command line argument, create a default vpc,subnet
# for that region (if one does not already exist)
#
# If no region was given as command line, walk through all Regions and
# the availability zones and create create any that are missing.
#
################################################################################

REPORT_RESULTS=""

#AWS_BIN="/Users/hhughes/Library/Python/2.7/bin/aws --profile thigpen --output text"
AWS_BIN="aws --profile thigpen --output text"

echo ""
echo "Restoring any and all missing default VPCs and Subnets in AWS ..."
echo ""

################################################################################

append_results()
{
  NEW_RESULT=$1

  REPORT_RESULTS="${REPORT_RESULTS}${NEW_RESULT}\n"
}

################################################################################

list_all_regions()
{
  echo "+==============================================================================+"
  echo "| List all regions in AWS ..."
  echo "+==============================================================================+"
  echo "|"
  # Single quotes for --query breaks this ...
  AWS_CMD="$AWS_BIN ec2 describe-regions --query Regions[*].RegionName"
  echo "|  > $AWS_CMD"
  echo "|"
  AWS_REGIONS=$($AWS_CMD)
  AWS_REGIONS=`echo $AWS_REGIONS | xargs -n1 | sort -u`   # Sort this list ...
  echo "|  AWS REGIONS:"
  echo "|"
  echo "|  +---------------------------------------------------------------------------+"
  for region in $AWS_REGIONS
  do
    echo "|  | $region"
  done
  echo "|  +---------------------------------------------------------------------------+"
  echo "|"
  echo "+==============================================================================+"
  echo
}

################################################################################

list_availability_zones()
{
  REGION=$1

  echo "|     +========================================================================+"
  echo "|     | List all availability zones in region ..."
  echo "|     +========================================================================+"
  echo "|     |"
  # Single quotes for --query breaks this ...
  AWS_CMD="$AWS_BIN ec2 --region $REGION describe-availability-zones --query AvailabilityZones[*].ZoneName"
  echo "|     |  > $AWS_CMD"
  echo "|     |"
  REGION_AZS=$($AWS_CMD)
  REGION_AZS=`echo $REGION_AZS | xargs -n1 | sort -u`   # Sort this list ...
  echo "|     |  REGION AVAILABILITY ZONES:"
  echo "|     |"
  echo "|     |  +---------------------------------------------------------------------+"
  for az in $REGION_AZS
  do
    echo "|     |  | $az"
  done
  echo "|     |  +---------------------------------------------------------------------+"
  echo "|     |"
  echo "|     +========================================================================+"
  echo "|"
}

################################################################################

create_default_vpc()
{
  #
  # NOTE: the 'create-default-vpc' action creates default subnets.
  #

  REGION=$1

  echo "|"
  echo "|     +------------------------------------------------------------------------+"
  echo "|     | Create new default-vpc for region: \"$REGION\" ..."
  echo "|     +------------------------------------------------------------------------+"
  echo "|"
  # Single quotes for --query breaks this ...
  AWS_CMD="$AWS_BIN --region $REGION ec2 create-default-vpc --query Vpc.VpcId"
  echo "|     > $AWS_CMD"
  DEFAULT_VPC_ID=$($AWS_CMD)
  echo "|"
  echo "|     => $DEFAULT_VPC_ID"
  echo "|"

  append_results "VPC created for $REGION: $DEFAULT_VPC_ID"
}

################################################################################

create_default_subnet()
{
  REGION=$1
  VPC_ID=$2
  AZ=$3
  VPC_CREATED_FLAG=$4

  echo "|        +---------------------------------------------------------------------+"
  echo "|        | Create new default-subnet for availbility-zone: \"$AZ\" ..."
  echo "|        +---------------------------------------------------------------------+"
  echo "|"
  # Single quotes for --query breaks this ...
  AWS_CMD="$AWS_BIN --region $REGION ec2 create-default-subnet --availability-zone $AZ --query Subnet.SubnetId"
  echo "|        > $AWS_CMD"
  DEFAULT_SUBNET_ID=$($AWS_CMD)
  echo "|"
  echo "|        => $DEFAULT_SUBNET_ID"
  echo "|"

  append_results "Subnet created for $az: $DEFAULT_SUBNET_ID"
}

################################################################################

create_default_subnets_if_needed()
{
  REGION=$1
  VPC_ID=$2
  VPC_CREATED_FLAG=$3

  REGION_AZS=""
  list_availability_zones $REGION           # Set REGION_AZS ...

  for az in $REGION_AZS
  do
    DEFAULT_SUBNET_ID=""
    does_default_subnet_exist $REGION $VPC_ID $az    # Sets DEFAULT_SUBNET_ID ...

    echo "|     => $DEFAULT_SUBNET_ID"
    echo "|"

    if [ "$DEFAULT_SUBNET_ID" == "None" ]; then
      echo "|     +------------------------------------------------------------------------+"
      echo "|     | No default subnet was found. Creating one."
      echo "|     +------------------------------------------------------------------------+"
      create_default_subnet $REGION $VPC_ID $az $VPC_CREATED_FLAG
    else
      if [[ $VPC_CREATED_FLAG = 1 ]]; then
        append_results "Subnet created for $az: $DEFAULT_SUBNET_ID"
      fi
    fi

  done
}

################################################################################

does_default_subnet_exist()
{
  REGION=$1
  VPC_ID=$2
  AZ=$3


  echo "|     +------------------------------------------------------------------------+"
  echo "|     | Test if default subnet exists for $AZ ..."
  echo "|     +------------------------------------------------------------------------+"
  echo "|"
  # Single quotes for --query breaks this ...
  AWS_CMD="$AWS_BIN --region $REGION ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID Name=availabilityZone,Values=$AZ Name=default-for-az,Values=true --query Subnets[0].[SubnetId]"
  echo "|     > $AWS_CMD"
  DEFAULT_SUBNET_ID=$($AWS_CMD)
  echo "|"
}

################################################################################

does_default_vpc_exist()
{
  REGION=$1
  echo "|  +---------------------------------------------------------------------------+"
  echo "|  | Test if default vpc exists ..."
  echo "|  +---------------------------------------------------------------------------+"
  echo "|"
  # Single quotes for --query breaks this ...
  AWS_CMD="$AWS_BIN --region $REGION ec2 describe-account-attributes --attribute-name default-vpc --query AccountAttributes[0].[AttributeValues]"
  echo "|  > $AWS_CMD"
  DEFAULT_VPC_ID=$($AWS_CMD)
  echo "|"
}

################################################################################

create_default_vpc_if_needed()
{
  REGION=$1
  DEFAULT_VPC_ID=""
  does_default_vpc_exist $REGION                # Sets DEFAULT_VPC_ID ...

  echo "|  => $DEFAULT_VPC_ID"
  echo "|"

  VPC_CREATED_FLAG=0

  if [ "$DEFAULT_VPC_ID" == "none" ]; then
    echo "|  +---------------------------------------------------------------------------+"
    echo "|  | No default vpc was found. Creating one."
    echo "|  +---------------------------------------------------------------------------+"
    create_default_vpc $REGION
    VPC_CREATED_FLAG=1
    echo "|  +---------------------------------------------------------------------------+"
    echo "|  | NOTE: VPC creation creates default-subnets ..."
    echo "|  +---------------------------------------------------------------------------+"
    echo "|"
  else
    echo "|  +---------------------------------------------------------------------------+"
    echo "|  | Test for any missing default subnets in this VPC ..."
    echo "|  +---------------------------------------------------------------------------+"
    echo "|"
  fi

  create_default_subnets_if_needed $REGION $DEFAULT_VPC_ID $VPC_CREATED_FLAG
}

################################################################################

AWS_REGION_ARG=$1
AWS_REGION=""
if [ "$AWS_REGION_ARG" != "" ]; then
  echo
  echo "Command line argument defining a single AWS region was found."
  echo "Building default VPC in only the region defined."
  echo
  AWS_REGION="--region $AWS_REGION_ARG"
  create_default_vpc_if_needed $AWS_REGION
else
  echo
  echo "Command line argument to define a single AWS region was not found."
  echo "Iterating through all regions."
  echo

  AWS_REGIONS=""                    # "us-east-1 us-east-2 us-west-1 us-west-2"
  list_all_regions                  # Sets AWS_REGIONS ...

  for region in $AWS_REGIONS
  do
    echo "+==============================================================================+"
    echo "| REGION: $region"
    echo "|"
    create_default_vpc_if_needed $region
    echo "|"
    echo "| REGION: $region ... done."
    echo "+==============================================================================+"
    echo
  done
fi

echo
echo "Changes to report:"
echo "--------------------------------------------------------------------------------"
if [ "$REPORT_RESULTS" = "" ]; then
  echo "None\n"
else
  echo $REPORT_RESULTS
fi

################################################################################
