  export EDITOR=nano

  clear

# Create vault
# ansible-vault create group_vars/all/vault
# Test variables
  ansible -m debug -a 'var=hostvars[inventory_hostname]' server
