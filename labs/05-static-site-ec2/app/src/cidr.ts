export interface CidrCalculation {
  input: string
  ipAddress: string
  prefixLength: number
  networkAddress: string
  broadcastAddress: string
  subnetMask: string
  wildcardMask: string
  firstUsableHost: string
  lastUsableHost: string
  totalAddresses: number
  usableHosts: number
  binary: {
    ipAddress: string
    networkAddress: string
    broadcastAddress: string
    subnetMask: string
    wildcardMask: string
  }
  hostRangeNote: string | null
}

export type CidrResult =
  | { ok: true; value: CidrCalculation }
  | { ok: false; errors: string[] }

const CIDR_PATTERN = /^([^/]+)(?:\/(.+))?$/

export function calculateCidr(input: string): CidrResult {
  const trimmed = input.trim()
  if (!trimmed) {
    return { ok: false, errors: ['Enter an IPv4 CIDR block, e.g. 192.168.1.0/24.'] }
  }

  const cidrMatch = trimmed.match(CIDR_PATTERN)
  if (!cidrMatch || cidrMatch[2] === undefined) {
    return { ok: false, errors: ['CIDR notation must include a prefix length, e.g. /24.'] }
  }

  const [, addressPart, prefixPart] = cidrMatch
  const errors: string[] = []
  const octets = parseIpv4(addressPart)
  const prefixLength = parsePrefix(prefixPart)

  if (!octets) {
    errors.push('IPv4 address must contain four decimal octets from 0 to 255.')
  }

  if (prefixLength === null) {
    errors.push('Prefix length must be a whole number from 0 to 32.')
  }

  if (errors.length > 0 || !octets || prefixLength === null) {
    return { ok: false, errors }
  }

  const ip = octetsToUint32(octets)
  const mask = prefixLength === 0 ? 0 : (0xffffffff << (32 - prefixLength)) >>> 0
  const wildcard = (~mask) >>> 0
  const network = (ip & mask) >>> 0
  const broadcast = (network | wildcard) >>> 0
  const totalAddresses = 2 ** (32 - prefixLength)
  const usableHosts = prefixLength >= 31 ? totalAddresses : Math.max(totalAddresses - 2, 0)

  const firstUsable = (() => {
    if (prefixLength === 32) return network
    if (prefixLength === 31) return network
    return (network + 1) >>> 0
  })()

  const lastUsable = (() => {
    if (prefixLength === 32) return network
    if (prefixLength === 31) return broadcast
    return (broadcast - 1) >>> 0
  })()

  const hostRangeNote = (() => {
    if (prefixLength === 32) return '/32 identifies a single host address.'
    if (prefixLength === 31) return '/31 is treated as a point-to-point network; both addresses are usable.'
    if (prefixLength === 0) return '/0 covers the entire IPv4 address space.'
    return null
  })()

  return {
    ok: true,
    value: {
      input: `${uint32ToIpv4(ip)}/${prefixLength}`,
      ipAddress: uint32ToIpv4(ip),
      prefixLength,
      networkAddress: uint32ToIpv4(network),
      broadcastAddress: uint32ToIpv4(broadcast),
      subnetMask: uint32ToIpv4(mask),
      wildcardMask: uint32ToIpv4(wildcard),
      firstUsableHost: uint32ToIpv4(firstUsable),
      lastUsableHost: uint32ToIpv4(lastUsable),
      totalAddresses,
      usableHosts,
      binary: {
        ipAddress: uint32ToBinary(ip),
        networkAddress: uint32ToBinary(network),
        broadcastAddress: uint32ToBinary(broadcast),
        subnetMask: uint32ToBinary(mask),
        wildcardMask: uint32ToBinary(wildcard),
      },
      hostRangeNote,
    },
  }
}

function parseIpv4(address: string): [number, number, number, number] | null {
  const parts = address.split('.')
  if (parts.length !== 4) return null

  const octets = parts.map((part) => {
    if (!/^\d+$/.test(part)) return null
    const value = Number(part)
    if (!Number.isInteger(value) || value < 0 || value > 255) return null
    return value
  })

  if (octets.some((octet) => octet === null)) return null
  return octets as [number, number, number, number]
}

function parsePrefix(prefix: string): number | null {
  if (!/^\d+$/.test(prefix)) return null
  const value = Number(prefix)
  if (!Number.isInteger(value) || value < 0 || value > 32) return null
  return value
}

function octetsToUint32([a, b, c, d]: [number, number, number, number]): number {
  return (((a << 24) >>> 0) | (b << 16) | (c << 8) | d) >>> 0
}

function uint32ToIpv4(value: number): string {
  return [
    (value >>> 24) & 0xff,
    (value >>> 16) & 0xff,
    (value >>> 8) & 0xff,
    value & 0xff,
  ].join('.')
}

function uint32ToBinary(value: number): string {
  return [
    (value >>> 24) & 0xff,
    (value >>> 16) & 0xff,
    (value >>> 8) & 0xff,
    value & 0xff,
  ]
    .map((octet) => octet.toString(2).padStart(8, '0'))
    .join('.')
}
