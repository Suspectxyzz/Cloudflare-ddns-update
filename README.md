# Cloudflare DNS Updater

This Bash script updates the IP address of specified `A` records in `Cloudflare DNS`, ensuring they match the current public IP. It checks the public IP using `api.ipify.org` and only updates the DNS records if a change is detected.

# Features:
- Updates multiple subdomains
- Checks current public IP
- Uses Cloudflare API for DNS updates
- Simple JSON parsing with jq
# Usage:

Set your Cloudflare API credentials and domain details in the script.
Ensure jq is installed.
Run the script to keep your DNS records up-to-date.



- For detailed API documentation, refer to the [Cloudflare API documentation](https://gist.github.com/marcostolosa/09615d10fa09e57071bbeeb7a5fd03ee)

- Status : `WORKS 20.6.2024`
