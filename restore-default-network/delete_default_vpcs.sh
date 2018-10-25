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
echo "Deleting any and all missing default VPCs and Subnets in AWS ..."
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

delete_default_vpc()
{
  #
  # NOTE: the 'create-default-vpc' action creates default subnets.
  #

  REGION=$1
  VPC_ID=$2

  echo "|"
  echo "|     +------------------------------------------------------------------------+"
  echo "|     | Delete default-vpc for region: \"$REGION\" ..."
  echo "|     +------------------------------------------------------------------------+"
  echo "|"
  # Single quotes for --query breaks this ...
  AWS_CMD="$AWS_BIN --region $REGION ec2 delete-vpc --vpc-id $VPC_ID"
  echo "|     > $AWS_CMD"
  DEFAULT_VPC_ID=$($AWS_CMD)
  echo "|"
  echo "|     => $DEFAULT_VPC_ID"
  echo "|"

  append_results "VPC deleted for $REGION: $DEFAULT_VPC_ID"
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

delete_default_vpc_if_needed()
{
  REGION=$1
  DEFAULT_VPC_ID=""
  does_default_vpc_exist $REGION                # Sets DEFAULT_VPC_ID ...

  echo "|  => $DEFAULT_VPC_ID"
  echo "|"

  if [ "$DEFAULT_VPC_ID" == "none" ]; then
    echo "|  +---------------------------------------------------------------------------+"
    echo "|  | No default vpc was found. Skipping region."
    echo "|  +---------------------------------------------------------------------------+"
    echo "|"
  else
    delete_default_vpc $REGION $DEFAULT_VPC_ID
    echo "|"
  fi
}

################################################################################

AWS_REGION_ARG=$1
AWS_REGION=""
if [ "$AWS_REGION_ARG" != "" ]; then
  echo
  echo "Command line argument defining a single AWS region was found."
  echo "Deleting default VPC in only the region defined."
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
    delete_default_vpc_if_needed $region
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
