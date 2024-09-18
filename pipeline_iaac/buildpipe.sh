#!/usr/bin/env bash

# Script to deploy a project on a CloudFormation
# Typical use: <script_name> [OPTION]...

#----------------------------------------------------------------------------------------------------------------------
function define_colors(){
    BLACK='\033[0;30m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    BROWN='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    LIGHT_GRAY='\033[0;37m'
    DARK_GRAY='\033[1;30m'
    LIGHT_RED='\033[1;31m'
    LIGHT_GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    LIGHT_BLUE='\033[1;34m'
    LIGHT_PURPLE='\033[1;35m'
    LIGHT_CYAN='\033[1;36m'
    WHITE='\033[1;37m'
    NC='\033[0m' # No Color
}
#----------------------------------------------------------------------------------------------------------------------
function check_command(){
    version_suffix=${2:---version}
    cmd_version=$($1 $version_suffix 2>&1 > /dev/null)
    if [ "$?" != "0" ]; then
        echo -e "${RED}Your environment doesn't have the ${LIGHT_RED}$1${RED} command. Exiting.${NC}"
        exit 2
    fi
}
#----------------------------------------------------------------------------------------------------------------------
function check_env(){
    check_command aws
    check_command git
}
#----------------------------------------------------------------------------------------------------------------------
function init(){
    repo_name=$(basename `git rev-parse --show-toplevel`)
    branch_name=$(git branch | grep \* | cut -d' ' -f2)
    dependency=false
    production=true
    email=$(aws iam get-user --query 'User.UserName' --output text)
    username=$(echo ${email%@*} | tr [:upper:] [:lower:])
    result_deploy=false
    noprompt=false
    verbosity='default'
    aws_cmd='aws'
}
#----------------------------------------------------------------------------------------------------------------------
function testing_mode__deploy(){
    echo -ne "${BROWN}\t *** TESTING MODE *** Deploy should be successful [y/N]? ${NC}"
    read -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        result_deploy=true
    else
        result_deploy=false
    fi
}
#----------------------------------------------------------------------------------------------------------------------
function deployment_header(){
    now=$(date +"%T")
    echo -e "\n${BLUE}Starting stack deployment at $now${NC}"
}
#----------------------------------------------------------------------------------------------------------------------
function deployment_main(){
    if $dependency ; then
        echo -e "\tDeploying pipeline...\n\t\trepo: $repo_name \n\t\tbranch: master \n\t...as a dependency (without branch name in the stack name)"
        $aws_cmd cloudformation deploy --stack-name $repo_name-pipeline-dependency --template-file code-pipeline.yml --parameter-overrides ProjectName=$repo_name Branch=master Username=$username Dependency=true Production=false
        result_deploy=$?
    else
        if $production ; then
            echo -e "\tDeploying pipeline...\n\t\trepo: $repo_name \n\t\tbranch: master \n\t${YELLOW}...on ProdEnvironment${NC}"
            $aws_cmd cloudformation deploy --stack-name $repo_name-pipeline-master --template-file code-pipeline.yml --parameter-overrides ProjectName=$repo_name Branch=master Username=$username Dependency=false Production=true
            result_deploy=$?
        else
            echo -e "\tDeploying pipeline...\n\t\trepo: $repo_name \n\t\tbranch: $branch_name \n\t...only on Tools"
            $aws_cmd cloudformation deploy --stack-name $repo_name-pipeline-$branch_name --template-file code-pipeline.yml --parameter-overrides ProjectName=$repo_name Branch=$branch_name Username=$username Dependency=false Production=false
            result_deploy=$?
        fi
    fi
    # testing_mode__deploy  # uncomment this only for testing purpose
}
#----------------------------------------------------------------------------------------------------------------------
function deployment_footer(){
    now=$(date +"%T")
    if [ "$result_deploy" == true ] || [ "$result_deploy" == "0" ] ; then
        echo -e "${LIGHT_GREEN}Stack deployment complete at $now${NC}"
    else
        echo -e "${LIGHT_RED}Stack deployment failed at $now${NC}"
    fi
}
#----------------------------------------------------------------------------------------------------------------------
function print_init(){
    msg=""
    msg="$msg${BLUE}Started with:${NC}\n"
    msg="$msg\tRepository name: ${LIGHT_BLUE}$repo_name${NC}\n"
    msg="$msg\tBranch name: ${LIGHT_BLUE}$branch_name${NC}\n"
    msg="$msg\tAs a dependency: ${LIGHT_BLUE}$dependency${NC}\n"
    msg="$msg\tProdEnvironment: ${LIGHT_BLUE}$production${NC}\n"

    case "$verbosity" in
    verbose)
        msg="$msg\tUsername: ${LIGHT_BLUE}$username${NC}\n"
        msg="$msg\tEmail: ${LIGHT_BLUE}$email${NC}\n"
        ;;
    quiet)
        msg=""
    esac
    echo -ne ${msg}
}
#----------------------------------------------------------------------------------------------------------------------
function confirm_deployment(){
    if $noprompt ; then
        deployment_header
    else
        echo -ne "\n${LIGHT_CYAN}Are you sure you want to deploy a stack [y/N]? "
        read -n 1 -r
        echo -e "${NC}"  # (optional) move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            deployment_header
        else
            if [ -z ${REPLY} ]; then
                echo -e "Your used the default ${YELLOW}N${NC}, so exiting."
                exit 0
            else
                echo -e "Your answer was ${YELLOW}${REPLY}${NC}, so exiting."
                exit 0
            fi
        fi
    fi
}
#----------------------------------------------------------------------------------------------------------------------

define_colors
check_env
init

#----------------------------------------------------------------------------------------------------------------------

# this shouldn't be a function due to easy and pleasant handling variables passed to this script

PARAMS=""

while (( "$#" )); do
  case "$1" in
    -u|--username)
      username=$2
      shift 2
      ;;
    -r|--repo)
      repo_name=$2
      shift 2
      ;;
    -b|--branch)
      branch_name=$2
      shift 2
      ;;
    -n|--new-branch)
      branch_name=$2
      msg=""
      msg="$msg${BLUE}Creating a new branch and pushing it...${NC}\n"
      msg="$msg\tChecking out branch ${branch_name}\n"
      msg="$msg\tgit pull\n"
      msg="$msg\tgit checkout -b ${branch_name}\n"
      msg="$msg\tgit push -u origin ${branch_name}\n"
      echo -e "${msg}"
      git pull origin master && git checkout -b ${branch_name} && git push -u origin ${branch_name}
      if [ "$?" != "0" ]; then
        echo -e "${RED}Cannot create and push a new branch ${LIGHT_RED}${branch_name}${RED}. Exiting.${NC}"
        exit 3
      fi
      shift 2
      ;;
    -d|--dependency)
      dependency=true
      branch_name='master'
      shift
      ;;
    -p|--production)
      production=true
      shift
      ;;
    -y|--yes)
      noprompt=true
      shift
      ;;
    -v|--verbose)
      verbosity='verbose'
      shift
      ;;
    -q|--quiet)
      verbosity='quiet'
      shift
      ;;
    -a|--aws-command)
      aws_cmd="$2"
      shift 2
      ;;
    -h|--help)
      msg=""
      msg="$msg${BROWN}Syntax: ./buildpipe.sh [OPTION]...${NC}\n"
      msg="$msg""Script will deploy a stack.\n"
      msg="$msg""\n"
      msg="$msg""-h, --help             shows this message\n"
      msg="$msg""-v, --verbose          be more verbose\n"
      msg="$msg""-q, --quiet            quiet output\n"
      msg="$msg""-y, --yes              don't ask about deployment, just do it\n"
      msg="$msg""-r, --repo NAME        provide a repo name if different than current one\n"
      msg="$msg""-b, --branch NAME      provide a branch name if different than working on\n"
      msg="$msg""-d, --dependency       deploy a stack as a dependency on Tools (without branch name in the stack name)\n"
      msg="$msg""-p, --production       deploy a stack to the ProdEnvironment (not working with -d|--dependency)\n"
      msg="$msg""-n, --new-branch       create a new branch from existing changes to the code and push them\n"
      msg="$msg""-u, --username         notify chosen user on Slack instead of you or on #deployments channel\n"
      msg="$msg""-a, --aws-command CMD  use 'CMD' instead 'aws' in the deploy commands\n"
      msg="$msg""\n"
      msg="$msg""Without any OPTION, current repo and branch name are used, dependency is set to false\n"
      msg="$msg""and production is also set to false, so that project can be safely deployed on Tools.\n"
      echo -e "$msg"
      exit 0
      ;;
    *) # preserve positional arguments
      PARAMS="$PARAMS $1"
      shift
      ;;
    -*|--*=) # unsupported flags
      echo -e "${RED}Error: Unsupported flag ${LIGHT_RED}$1${NC}" >&2
      exit 1
      ;;
#    --) # end argument parsing
#      shift
#      break
#      ;;
  esac
done  # set positional arguments in their proper place

eval set -- "$PARAMS"
#----------------------------------------------------------------------------------------------------------------------

print_init
confirm_deployment
deployment_main
deployment_footer

#----------------------------------------------------------------------------------------------------------------------