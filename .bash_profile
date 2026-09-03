#this is to set up a new bash rc file

[[ $- == *i* ]] && echo "hello Benj, welcome to the Matrix"

source $HOME/dotfiles/bin/session-sauce.plugin.zsh
export SESS_PROJECT_ROOT="$HOME/Projects:$HOME/go/src/github.com/vendasta"

export BASH_SILENCE_DEPRECATION_WARNING=1

function nonzero_return() {
	RETVAL=$?
	[ $RETVAL -ne 0 ] && echo "[$RETVAL] "
}

# get current branch in git repo
function parse_git_branch() {
	BRANCH=`git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
	if [ ! "${BRANCH}" == "" ]
	then
		STAT=`parse_git_dirty`
		echo " [${BRANCH}${STAT}]"
	else
		echo ""
	fi
}

# get current status of git repo
function parse_git_dirty {
	status=`git status 2>&1 | tee`
	dirty=`echo -n "${status}" 2> /dev/null | grep "modified:" &> /dev/null; echo "$?"`
	untracked=`echo -n "${status}" 2> /dev/null | grep "Untracked files" &> /dev/null; echo "$?"`
	ahead=`echo -n "${status}" 2> /dev/null | grep "Your branch is ahead of" &> /dev/null; echo "$?"`
	newfile=`echo -n "${status}" 2> /dev/null | grep "new file:" &> /dev/null; echo "$?"`
	renamed=`echo -n "${status}" 2> /dev/null | grep "renamed:" &> /dev/null; echo "$?"`
	deleted=`echo -n "${status}" 2> /dev/null | grep "deleted:" &> /dev/null; echo "$?"`
	bits=''
	if [ "${renamed}" == "0" ]; then
		bits=">${bits}"
	fi
	if [ "${ahead}" == "0" ]; then
		bits="*${bits}"
	fi
	if [ "${newfile}" == "0" ]; then
		bits="+${bits}"
	fi
	if [ "${untracked}" == "0" ]; then
		bits="?${bits}"
	fi
	if [ "${deleted}" == "0" ]; then
		bits="x${bits}"
	fi
	if [ "${dirty}" == "0" ]; then
		bits="!${bits}"
	fi
	if [ ! "${bits}" == "" ]; then
		echo " ${bits}"
	else
		echo ""
	fi
}

if type rg &> /dev/null; then
  export FZF_DEFAULT_COMMAND="rg --files-with-matches --hidden '.' --glob '!.git'"
  export FZF_DEFAULT_OPTS='-m --height 50% --border'
fi
# Use ~~ as the trigger sequence instead of the default **
#export FZF_COMPLETION_TRIGGER='~~'
# Options to fzf command
#export FZF_COMPLETION_OPTS='--border --info=inline'


# https://github.com/garabik/grc: To set aliases for supported commands
[[ -s "/etc/grc.sh" ]] && source /etc/grc.sh

# custom path for vendasta box
PATH=$PATH:$HOME/google-cloud-sdk/bin
PATH=$PATH:/usr/local/mysql/bin
# Add Visual Studio Code (code)
#PATH=$PATH:/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin

export GOPATH=$HOME/go
export GOBIN=$GOPATH/bin
export PATH=$GOBIN:$PATH
export GO111MODULE=auto
export GOPRIVATE="github.com/vendasta"

export VIMINIT='source $MYVIMRC'
export MYVIMRC='~/dotfiles/vimide/.vimrc'
export EDITOR=nvim
export SCPSSH="scp bvh895@tuxworld.usask.ca:/student/bvh895/"
export PS1="\[\e[31m\]\`nonzero_return\`\[\e[m\]\[\e[0;32m\]\A\[\e[m\] \h:\[\e[0;36m\]\W\[\e[m\]\[\e[32m\]\`parse_git_branch\`\[\e[m\]\n\[\e[31m\]♥\[\e[m\] "

# NES_TOKEN - can't recall where this comes from
[ -f "$HOME/.bash_secrets" ] && source "$HOME/.bash_secrets"

#==================
# Yesware Env Vars
#==================
# Secrets: GOOGLE_OAUTH2_ID, GOOGLE_OAUTH2_SECRET, FURY_TOKEN,
#          RSPEC_S3_ACCESS_KEY, RSPEC_S3_PRIVATE_KEY, NEW_RELIC_API_KEY
export YW_GIT_NAME="Benj Hingston"
export YW_GIT_EMAIL="benjhingston@gmail.com"
export YWSTART_REPO_DIR="$HOME/Projects"
# As of Postgres 12, we've gotten crashes locally unless we set this flag:
export PGGSSENCMODE="disable"
export AWS_REGION="us-east-1"
# To avoid facing a timeout whenever you open the localdev environment for the first time, you can disable Rack::Timeout by adding
export RACK_TIMEOUT_SERVICE_TIMEOUT=0

#export SALES_SSL_ROOT=$HOME/Projects/keys/sales-psql
## TODO: only set if it is unset
#if [ -z "$SALES_PASSWD" ]
#then
#	echo "setting sales password for psql"
#	export SALES_PASSWD=$(kubectl -n sales-demo get secret postgresql-user -o jsonpath="{.data.password}" | base64 --decode);
#	echo "sales psql password set"
#fi

# for galaxy OOM javascript heap errors
export NODE_OPTIONS=--max_old_space_size=12000
#export SvnPrj=$SvnURL/time_calc;

# run tmux at start of each window
#if [[ -z "$TMUX" ]]; then
#	tmux
#fi

#===================
# Personnal Aliases
#===================
# alias go="grc go" # grc is broken for now; I messed up my python environment
alias ls="ls -pG"
alias hs="history | grep"
alias sshusask="ssh bvh895@tuxworld.usask.ca"
alias gc="gcloud"
alias bashrc="~/.bash_profile"
alias vim='command nvim' vio='command vim'
eval $(thefuck --alias)
# You can use whatever you want as an alias, like for Mondays:
eval $(thefuck --alias fuck)

#===================
# WSU Notes
#===================
function wsu-note() {
  if [ -z "$*" ]; then
    echo "Usage: wsu-note <note>"
    return 1
  fi
  local dir="$HOME/.claude/wsu"
  local file="$dir/$(date +%G-W%V).md"
  mkdir -p "$dir"
  echo "- $(date '+%Y-%m-%d %H:%M')  $*" >> "$file"
  echo "Noted."
}

function wsu-log() {
  local file="$HOME/.claude/wsu/$(date +%G-W%V).md"
  if [ -f "$file" ]; then
    cat "$file"
  else
    echo "No notes yet this week."
  fi
}

#=+++++++++==================
# Vendasta & Yesware Aliases
#=========+++++++++==========
#alias invfuck="inv pylint -f pylint_test -f test"

alias npx="npx --no-install"

alias hsb="AWS_PROFILE=yesware-bmo helm secrets"
alias hss="AWS_PROFILE=yesware-staging helm secrets"
alias hsp="AWS_PROFILE=yesware-production helm secrets"

alias webpack="npx webpack"
alias gulp="npx gulp"
alias lerna="npx lerna"

alias nginx-start='sudo brew services start nginx'
alias nginx-stop='sudo brew services stop nginx'

alias docker-start="docker compose -f ~/Projects/dev-services/docker-compose.yml up -d"
alias docker-stop="docker compose -f ~/Projects/dev-services/docker-compose.yml stop"

alias rmap="repository-mapper"

invfuck() {
	if [ $# -eq 0 ]; then
		inv pylint -f
		inv pylint_test -f
		inv test
	fi
}

lintit() {
	npx nx affected:lint --base=origin/master --parallel
}

testit() {
	npx nx affected:test --base=origin/master --ci --maxWorkers=4 --parallel --silent
}

fuckit() {
	npx nx affected:lint --base=origin/master --parallel
	npx nx affected:test --base=origin/master --ci --maxWorkers=4 --parallel --silent
	npm run affected:lint:styles
	npx nx affected:build --base=origin/master --with-deps --prod --parallel --maxParallel=5
}

# Get current weather, with option of giving town as arg
#alias weather="curl wttr.in"
weather() {
	if [ $# -eq 0 ]; then
		curl wttr.in
	else
		curl wttr.in/~$1
	fi
}

mkpdf() {
	if [ $# -eq 1 ]; then
		filename=$1
		pdflatex $filename
		open "${filename%.*}.pdf"
	fi
}

export PATH=$PATH":$HOME/bin"

export PATH="$HOME/.local/bin:$PATH"

export PATH="$HOME/.cargo/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="usr/local/sbin:$PATH"

start_spinner() {
  local pid=$1
  local delay=0.1

  # Pick a spinner style: dots, waves, etc.
  # local spinner_frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")  # Braille dots
  # local spinner_frames=("▖" "▘" "▝" "▗")  # Quarter circles
  # spinner_frames=("▁" "▃" "▄" "▅" "▆" "▇" "█" "▇" "▆" "▅" "▄" "▃")  # 🌊 Wave style spinner
  local spinner_frames=("▁ " "▄▁" "▅▃" "▆▄" "█▅" "▇█" "▆▇" "▅▆" "▄▅" "▃▄" "▁▃")  # 🌊 Wave style spinner
  # local spinner_frames=("←" "↖" "↑" "↗" "→" "↘" "↓" "↙")  # Arrows
  # local spinner_frames=("-" "\\" "|" "/")  # Classic fallback

  local i=0
  while ps -p "$pid" &>/dev/null; do
    printf " [%s]  " "${spinner_frames[$i]}"
    i=$(( (i + 1) % ${#spinner_frames[@]} ))
    sleep $delay
    printf "\b\b\b\b\b\b\b"  # 6 \b for single char and 7 for double char
  done
  printf "    \b\b\b\b"
}

# nvm setup with spinner (interactive shells only — skips Claude Code / non-interactive bash)
if [[ $- == *i* ]] && type nvm &> /dev/null; then
  echo -n "Setting up Node.js with nvm..."
  (
    nvm alias default 20 &> /dev/null
    nvm use default &> /dev/null
  ) &
  spinner_pid=$!
  start_spinner $spinner_pid
  wait $spinner_pid
  echo " Done!"
fi

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

# Added by `rbenv init` on Wed 24 Sep 2025 15:12:55 CST
eval "$(rbenv init - --no-rehash bash)"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
