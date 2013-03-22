#!/bin/bash
#
# -*-Shell-script-*-
#
# go_functions.sh Functions to be used by various Virtuoso-related scripts


export GO_SCRIPT_BUG LOCK_TSTAMP LOCK_OTHER ROUND_ROBIN_SEED ROUND_ROBIN_LOCK_INDEX
ROUND_ROBIN_SEED=`date +%N`

report_passed()
{
  echo "PASSED: $1"
}

report_failed()
{
  echo "***FAILED: $1"
}

report_script_bug()
{
  echo "***FAILED: SCRIPT BUG: $1"
}

report_pf_if2()
{
  if [ "$1" $2 "$3" ] ; then report_passed "$4" ; else report_failed "$4" ; fi
}

report_script_bug()
{
  report_pf_if2 "$GO_SCRIPT_BUG" '!=' '' "SCRIPT BUG ASSERTION: $1"
}


create_lock_file()
{
  lock_name="$1"
  tstamp=`date +%FT%T.%N%:z`
  own_msg="$tstamp $2"
  if [ -f "$lock_name" ] ; then
    LOCK_OTHER=`cat $lock_name`
    LOCK_TSTAMP=''
    return 1
  fi
  set -o noclobber
  echo "$own_msg" > $lock_name && locked='Y'
  set +o noclobber
  if [ "$locked" = 'Y' ] ; then
    if [ -f "$lock_name" ] ; then
      LOCK_TSTAMP="$tstamp"
      return 0
    fi
    LOCK_OTHER="The lock file $lock_name is not owned because it cannot be created at all"
    LOCK_TSTAMP=''
    return 2
  fi
  LOCK_OTHER=`cat $lock_name`
  LOCK_TSTAMP=''
  return 2
}

create_round_robin_lock_file()
{
  lock_name_base="$1"
  n_from="$2"
  n_to="$3"
  own_msg="$tstamp $4"
  if expr '(' 0 '<' match "$n_from" '[0-9]\+$' ')' '&' '(' 0 '<'  match "$n_to" '[0-9]\+$' ')' '&' '(' "$n_from" '<' "$n_to" ')' > /dev/null
  then
    ctr=$n_from
    while expr $ctr '<' $n_to > /dev/null ; do
      idx=`expr $n_from '+' '(' $ROUND_ROBIN_SEED '%' '(' $n_to '-' $n_from ')' ')'`
      ROUND_ROBIN_SEED=`expr $ROUND_ROBIN_SEED '+' 1`
      if create_lock_file "$lock_name_base.$idx.lck" "$own_msg" ; then
        ROUND_ROBIN_LOCK_INDEX=$idx
        return 0
      fi
      ctr=`expr $ctr '+' 1`
    done
  fi
  report_script_bug "wrong args [$n_from] and [$n_to] of create_round_robin_lock_file() or too many attempts of making a lock $lock_name_base.XXX.lck"
  ROUND_ROBIN_LOCK_INDEX=''
  return 1
}

go_functions_self_test()
{
  echo starting self_test
  create_lock_file $HOME/go_functions.self-test.lck 'Lock file for self_test'
  report_pf_if2 "$LOCK_TSTAMP" '!=' '' 'Lock of self_test is set'
  my_tstamp="$LOCK_TSTAMP"
  create_lock_file $HOME/go_functions.self-test.lck 'Redundand lock file for self_test'
  report_pf_if2 "$LOCK_TSTAMP" '==' '' 'Redundand lock of self_test is rejected'
  create_lock_file /nosuchdirectory/go_functions.self-test.lck 'Bad path lock file for self_test'
  report_pf_if2 "$LOCK_TSTAMP" '==' '' 'Bad path lock of self_test is rejected'
  create_round_robin_lock_file $HOME/go_functions.self-test-rr 1000 1003 'Round-robin lock 1/3 for self_test'
  report_pf_if2 "$ROUND_ROBIN_LOCK_INDEX" '!=' '' 'Round-robin lock 1/3'
  create_round_robin_lock_file $HOME/go_functions.self-test-rr 1000 1003 'Round-robin lock 2/3 for self_test'
  report_pf_if2 "$ROUND_ROBIN_LOCK_INDEX" '!=' '' 'Round-robin lock 2/3'
  create_round_robin_lock_file $HOME/go_functions.self-test-rr 1000 1003 'Round-robin lock 3/3 for self_test'
  report_pf_if2 "$ROUND_ROBIN_LOCK_INDEX" '!=' '' 'Round-robin lock 3/3'
  GO_SCRIPT_BUG='Y'
  create_round_robin_lock_file $HOME/go_functions.self-test-rr 1000 1003 'Round-robin lock 4/3 for self_test'
  GO_SCRIPT_BUG=''
  report_pf_if2 "$ROUND_ROBIN_LOCK_INDEX" '==' '' 'Redundand round-robin lock 4/3'
  rm -rf $HOME/go_functions.self-test.lck
  rm -rf $HOME/go_functions.self-test-rr.*.lck
}

if [ "$1" = "self_test" ]
then
  go_functions_self_test
fi
