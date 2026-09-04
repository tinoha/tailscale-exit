# providers.tf

# Microsoft Azure Provider. Authenticates with the caller's own Entra ID
# account (az login). RP registration below happens at subscription scope;
# if the running identity is scoped to the anchor resource group only, the
# resource providers must be pre-registered on the subscription instead.
provider "azurerm" {
  resource_providers_to_register = [
    "Microsoft.Compute",
    "Microsoft.Network",
    "Microsoft.Storage",
    "Microsoft.DevTestLab",
  ]

  features {}
}
