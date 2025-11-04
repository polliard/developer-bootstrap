# 1) Put the Makefile into your bootstrap repo folder
#    e.g., ~/Workspace/dev-bootstrap
#    then from inside that folder:
make install
make verify

# 2) Add the helper CLI to your PATH (if you haven’t already)
mkdir -p ~/bin
cp ~/Downloads/createProject ~/bin/createProject   # or to wherever you downloaded it
chmod +x ~/bin/createProject
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
