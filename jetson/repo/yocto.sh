echo "ShuraCore welcomes you!" 
echo "This is a script for building a Linux image for Red Panda 1b"

if [ -d "./tegra-demo-distro" ] 
then
    echo "Directory tegra-demo-distro exists" 
        
    cd ./tegra-demo-distro    
    
    #setup env
    . ./setup-env --machine jetson-nano-devkit
        
    #check current state
    bitbake-layers show-layers
    
    #build
    bitbake demo-image-full    
else
    echo "Clone tegra-demo-distro" 
    
    #git clone tegra-demo-distro
    git clone https://github.com/OE4T/tegra-demo-distro.git
    cd tegra-demo-distro/

    #kirkstone
    git checkout kirkstone
    git submodule update --init
    
    cd layers/
    git clone https://github.com/meta-qt5/meta-qt5.git
    cd meta-qt5
    #kirkstone
    git checkout kirkstone
    
    cd ../../
    
    #setup env
    . ./setup-env --machine jetson-nano-devkit

    #bitbake
    echo "Add qt5-meta layer" 
    #check current state
    bitbake-layers show-layers
    #add qt5
    bitbake-layers add-layer /home/user/tegra-demo-distro/layers/meta-qt5    
    #check state
    bitbake-layers show-layers
    #build
    bitbake demo-image-full
fi

if [ ! -d "/home/user/artifact" ] 
then
    cd /home/user/
    mkdir artifact
fi

cd /home/user/artifact
rm -rf *
cd /home/user/tegra-demo-distro/build/tmp/deploy/images/jetson-nano-devkit
cp demo-image-full-jetson-nano-devkit.tegraflash.tar.gz /home/user/artifact
cd /home/user/artifact
tar xzvf demo-image-full-jetson-nano-devkit.tegraflash.tar.gz

echo "Completed" 

