#!/bin/bash

root=~/sw/jedit/plugins
log=$root/.build.log

run_log()
{
   echo $* >> $log
   $* &>> $log || exit
}

echo_log()
{
   echo $* | tee -a $log
}


echo_log "Building plugins [" `date` "]"

# any arg on the cmd line will skip building
if [[ -n "$1" ]]; then
   skipBuilding=1
   echo_log "Not building, just updating..."
else
   echo_log "Updating and building..."
fi

git_sync_with_remote()
{
   run_log git merge --ff-only
   
   branch=$(git symbolic-ref -q HEAD)
   branch=${branch##refs/heads/}
   if [[ "$branch" != "master" ]]; then
      run_log git merge --ff-only master
      
      master_sha1=`git show-ref refs/heads/master | cut -d' ' -f1`
      common_sha1=$(git merge-base HEAD master)
      if [[ "$master_sha1" != "$common_sha1" ]]; then
         echo_log "New changes merged from master; need to push!"
      fi
   fi
}

# args:
#  $1 = plugin name (folder)
#  $2 = repo type (optional, defaults to 'svn', other values are: 'git', 'git-svn')
#  $3 = build command (optional, defaults to 'ant')
build()
{
   echo_log "== $1 =="
   run_log cd "$root"
 
   ant_cmd="ant"
   if [[ -n "$3" ]]; then
      ant_cmd="$3"
   fi

   repo_type="svn"
   if [[ -n "$2" ]]; then
      repo_type="$2"
   fi
   if [[ "$repo_type" != "svn" && "$repo_type" != "git" && "$repo_type" != "git-svn" ]]; then
      echo_log "unknown repo type '$2'"
      exit
   fi

   # check if the folder exists, if not then checkout/clone it
   if [[ ! -e "$root/$1" ]]; then
      echo_log "Checking out new copy of plugin..."
      
      if [[ "$repo_type" == "svn" ]]; then
         run_log svn co https://jedit.svn.sourceforge.net/svnroot/jedit/plugins/$1/trunk $1
      elif [[ "$repo_type" == "git" ]]; then
         run_log git clone git://jedit.git.sourceforge.net/gitroot/jedit/$1
      elif [[ "$repo_type" == "git-svn" ]]; then
         # run_log git svn init -s https://jedit.svn.sourceforge.net/svnroot/jedit/plugins/$1 $1
         run_log git clone git@github.com:zjg/jedit-$1.git $1
      fi
   fi

   run_log cd "$root/$1"
   if [[ "$repo_type" == "svn" ]]; then
      run_log svn up
   elif [[ "$repo_type" == "git" ]]; then
      run_log git fetch --all
      git_sync_with_remote
      
   elif [[ "$repo_type" == "git-svn" ]]; then
      run_log git svn fetch
      run_log git fetch --all
      
      remotes=$(git remote)
      if [[ -n "$remotes" ]]; then
         git_sync_with_remote
      fi
   fi
   if [[ -z "$skipBuilding" ]]; then
      run_log $ant_cmd
   fi
}

# stuff with no deps on other plugins
build "CommonControls"
build "Code2HTML"
build "ErrorList"
build "InfoViewer"
build "JNAPlugin"
build "MarkerSets" git "ant build"
build "SuperAbbrevs"
build "Tags"
build "TextTools"
build "GnuRegexp"
build "CandyFolds"
# build "ColumnRuler"
build "Hex" svn "ant build"
build "Highlight"
build "LookAndFeel"
build "TextTools"
build "WhiteSpace" svn "ant build"
build "FTP"

# stuff that depends on other plugins - order matters here!
build "Activator"             # CommonControls
build "ProjectViewer" git     # CommonControls, ErrorList, InfoViewer
build "LucenePlugin"          # MarkerSets, ProjectViewer
build "Completion" git        # SuperAbbrevs
build "Navigator"             # Code2HTML, ProjectViewer
build "CtagsInterface" git    # ProjectViewer, SuperAbbrevs, Navigator, Lucene, Completion
build "ClassBrowser" git "ant build"   # CtagsInterface
build "BufferList" git-svn    # GnuRegexp
build "Console"               # ProjectViewer, ErrorList
build "EditorScheme"          # CommonControls
build "SshConsole"            # ErrorList, FTP, Console
build "FastOpen" git-svn      # ProjectViewer


#build "RecursiveOpen"        # doesn't exist??
#build "SwitchBuffer" git     # I've implemented the functionality I liked in FastOpen
