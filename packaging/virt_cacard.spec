Name:		virt_cacard
Version:	1.2.1
Release:        %autorelease
Summary:	Virtual CAC Card

License:	GPLv3
URL:		https://github.com/Jakuje/virt_cacard/
Source0:	https://github.com/Jakuje/virt_cacard/releases/download/%{name}-%{version}/%{name}-%{version}.tar.gz

BuildRequires:	pcsc-lite-devel
BuildRequires:	gcc
BuildRequires:	autoconf
BuildRequires:	automake
BuildRequires:	libtool
BuildRequires:	libcacard-devel
# the call to pkill through system()
Recommends:     procps-ng

%description
Simple application to emulate CAC Smart cards on PC/SC layer

%prep
%autosetup -p1

%build
./autogen.sh
%configure
%make_build

%install
%make_install

%files
%license LICENSE
%doc README.md
%{_bindir}/virt_cacard

%changelog
%autochangelog
