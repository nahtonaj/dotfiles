# Auto-generated from configs/aliasrc for Fish shell
# Do not edit directly.

fish_add_path /apollo/env/BarkCLI/bin
fish_add_path /apollo/env/DdbStorageApiOncallTools/bin
fish_add_path /home/jonatgao/workplace/ddblogservicepythontools/src/DdbLogServicePythonTools/bin
fish_add_path /apollo/env/CarnavalCLITools/bin
fish_add_path $HOME/.toolbox/bin
fish_add_path /usr/local/bin
fish_add_path /home/linuxbrew/.linuxbrew/bin
fish_add_path /home/linuxbrew/.linuxbrew/sbin
fish_add_path /apollo/env/envImprovement/bin
fish_add_path /home/jonatgao/.cargo/bin
fish_add_path /home/jonatgao/.sdkman/candidates/java/current/bin
fish_add_path $HOME/.rodar/bin
fish_add_path /apollo/sbin
fish_add_path $HOME/workplace/dotfiles/scripts
set -gx EDITOR nvim


alias bb 'brazil-build'

alias bba 'brazil-build apollo-pkg'
alias bre 'brazil-runtime-exec'
alias brc 'brazil-recursive-cmd'
alias brca 'brazil-recursive-cmd --allPackages'
alias bws 'brazil ws'
alias bwsuse 'bws use --gitMode -p'
alias bwscreate 'bws create -n'
alias brc 'brazil-recursive-cmd'
alias bbr 'brc brazil-build'
alias bball 'brc --allPackages'
alias bbb 'brc --allPackages brazil-build'
alias bbbb 'brc --allPackages brazil-build build'
alias bbra 'bbr apollo-pkg'
alias kw 'kinit -f && mwinit -o -s'
alias barkd 'bark -cf=/home/$USER/.barkDub'
alias ic 'isengardcli'
alias sshy 'ssh -o StrictHostKeyChecking=no'
alias bbmysql 'sudo mysql -S /tmp/mysql45691.sock -uroot -proot'
alias bbvisualizewatch 'brazil-build visualize & brazil-build visualize-watch && fg'
alias ta 'tmux a'
alias emacs 'emacsclient -c -a \'emacs\''
alias lptvc '/apollo/env/CatalystResourceCreationClientTools/bin/LptVerifierCli --lpt-verifier-action static_analysis --lpt-app-def build/application_definition.json'
set -gx TEST_RUNTIME /local/home/jonatgao/workplace/bigbirdstoragenode/src/BigBirdStorageNode/build/private/tmp/BigBirdStorageNode
set -gx LN_TEST_STORAGENODE /local/home/jonatgao/workplace/ddblognode/src/BigBirdStorageNode/build/private/tmp/BigBirdStorageNode
set -gx LN_TEST_RUNTIME /local/home/jonatgao/workplace/ddblognode/src/DdbLogNodeTest/build/private/tmp/BigBirdStorageNode
alias setuptestruntime './testbin/setup-test-runtime -s -b -n -e $TEST_RUNTIME'
alias setuplntestruntime './testbin/setup-test-runtime -s -b -n -e $LN_TEST_RUNTIME'

# get current date in Pacific time






alias sc 'scratch && pwd'









# Enables autocompletion for the ddb command - Installed by MechanicBigBirdCli


# Add AmazonAwsCli bin directory to PATH for isengard command
fish_add_path /apollo/env/AmazonAwsCli/bin

# GTAS local server helper function

# GTAS DUB local server helper function
# Q Chat alias with comprehensive read-only tools
