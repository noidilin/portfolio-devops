# install log monitor to observer the log within container
FROM diamol/base:2e AS logmonitor
ARG LOGMONITOR_VERSION="v1.1"
ADD https://github.com/microsoft/windows-container-tools/releases/download/${LOGMONITOR_VERSION}/LogMonitor.exe .

# the dotnet framework version comes from requirement
FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# copy the logmonitor from the previous stage
# configuration file for LogMonitor is expected at the path `C:\LogMonitor\LogMonitorConfig.json`
COPY --from=logmonitor /LogMonitor.exe /LogMonitor.exe
# the config file is provided by the lab
COPY LogMonitorConfig.json /LogMonitor/

# install with msiexec tool
COPY SignUp-1.0.msi /
RUN Start-Process msiexec.exe -ArgumentList '/i', 'C:\SignUp-1.0.msi', '/quiet', '/norestart' -NoNewWindow -Wait

# entrypoint for container is `LogMonitor.exe`
# which needs to call `ServiceMonitor.exe` with the parameter `w3svc` to start the chain of monitoring the IIS Windows Service
WORKDIR /
ENTRYPOINT ./LogMonitor.exe ServiceMonitor.exe w3svc
