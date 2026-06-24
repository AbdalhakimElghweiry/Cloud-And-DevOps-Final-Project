variable "location" {
  type        = string
  description = "Azure region for all project resources"
  default     = "swedencentral"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that contains all project resources"
  default     = "rg-abdalhakim-finalproject"
}

variable "acr_name" {
  type        = string
  description = "Azure Container Registry name — must be globally unique, 5-50 chars, lowercase alphanumeric only"
  default     = "abdalhakimfinalacr"
}

variable "aks_cluster_name" {
  type        = string
  description = "AKS cluster name"
  default     = "aks-abdalhakim-finalproject"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the default node pool"
  default     = 2
}

variable "node_size" {
  type        = string
  description = "VM size for AKS nodes"
  default     = "Standard_B2s_v2"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default = {
    Project     = "Final"
    StudentName = "Abdalhakim Elghweiry"
  }
}
