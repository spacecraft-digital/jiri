Running Jiri in Production
==========================

## Installation
Install Node.js
```
npm install -g forever
cd /var
git clone <path to git repo> jiri
```

## Run
Paste in env vars
```
forever start -c 'npm start' /var/jiri/
```

`forever` will restart Jiri if he crashes.
