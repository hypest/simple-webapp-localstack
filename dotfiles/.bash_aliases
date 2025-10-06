# Project dotfiles: shared aliases for the devcontainer

# Show running containers: id, image, status, names
alias dps='docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"'

# Docker compose shorthand
alias dc='docker compose'

# Rails / project shortcuts
alias rs='bin/dev'   # start rails server using the dev script (adjust if you use `bin/rails server`)
alias rc='bin/rails console'
alias rdb='bin/rails dbconsole'

# Git and convenience
alias g='git'
alias ll='ls -lha'

# Add more aliases below as needed
