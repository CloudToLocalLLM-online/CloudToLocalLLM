Name:           cloudtolocalllm
Version:        1.0.0
Release:        1%{?dist}
Summary:        Manage and run powerful Large Language Models locally, orchestrated via a cloud interface

License:        MIT
URL:            https://cloudtolocalllm.online
Source0:        %{name}-%{version}-linux.tar.gz

BuildArch:      x86_64
BuildRequires:  tar
Requires:       gtk3 libX11 libXcursor libXfixes libXi libXinerama libXrandr

%description
CloudToLocalLLM is a desktop application that allows you to manage and run powerful Large Language Models locally, with a cloud-based interface for orchestration.

%prep
%setup -q -n %{name}-%{version}-linux

%build
# No build step needed - this is a pre-built Flutter application

%install
mkdir -p %{buildroot}/opt/%{name}
cp -r * %{buildroot}/opt/%{name}/

# Create symlink in /usr/bin
mkdir -p %{buildroot}/usr/bin
ln -sf /opt/%{name}/cloudtolocalllm %{buildroot}/usr/bin/cloudtolocalllm

# Create desktop entry
mkdir -p %{buildroot}/usr/share/applications
cat > %{buildroot}/usr/share/applications/%{name}.desktop << 'EOF'
[Desktop Entry]
Name=CloudToLocalLLM
Comment=Manage and run powerful Large Language Models locally
Exec=/opt/%{name}/cloudtolocalllm
Icon=%{name}
Terminal=false
Type=Application
Categories=Development;Utility;Network;
EOF

# Create icon directory (if icon exists)
if [ -f data/flutter_assets/assets/icons/icon.png ]; then
    mkdir -p %{buildroot}/usr/share/pixmaps
    cp data/flutter_assets/assets/icons/icon.png %{buildroot}/usr/share/pixmaps/%{name}.png
fi

%files
%defattr(-,root,root,-)
/opt/%{name}
/usr/bin/cloudtolocalllm
/usr/share/applications/%{name}.desktop
%{_datadir}/pixmaps/%{name}.png

%changelog
* %(date +"%a %b %d %Y") CloudToLocalLLM Team <support@cloudtolocalllm.online> - 1.0.0-1
- Initial RPM package for CloudToLocalLLM

