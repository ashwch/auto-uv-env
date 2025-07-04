Name:           auto-uv-env
Version:        1.0.4
Release:        1%{?dist}
Summary:        Automatic UV-based Python virtual environment management

License:        MIT
URL:            https://github.com/ashwch/auto-uv-env
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildArch:      noarch
Requires:       bash >= 4.0
Recommends:     uv

%description
auto-uv-env automatically activates Python virtual environments when
you navigate to Python projects. It detects pyproject.toml files,
creates virtual environments using UV, and manages activation/deactivation
seamlessly.

Features:
- Automatic virtual environment activation
- UV-powered for fast environment creation
- Multi-shell support (Bash, Zsh, Fish)
- Zero configuration required

%prep
%autosetup

%build
# Nothing to build

%install
# Install main script
install -D -m 755 auto-uv-env %{buildroot}%{_bindir}/auto-uv-env

# Install shell integrations
mkdir -p %{buildroot}%{_datadir}/%{name}
install -m 644 share/auto-uv-env/* %{buildroot}%{_datadir}/%{name}/

%files
%license LICENSE
%doc README.md CHANGELOG.md
%{_bindir}/auto-uv-env
%{_datadir}/%{name}/

%changelog
* Thu Jul 03 2025 Ashwini Chaudhary <ashwch@example.com> - 1.0.4-1
- Initial RPM package
