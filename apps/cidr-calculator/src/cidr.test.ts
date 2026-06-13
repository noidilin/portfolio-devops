import { describe, expect, it } from 'vitest'
import { calculateCidr } from './cidr'

function expectValid(input: string) {
  const result = calculateCidr(input)
  expect(result.ok).toBe(true)
  if (!result.ok) throw new Error(result.errors.join(', '))
  return result.value
}

describe('calculateCidr', () => {
  it('calculates a common /24 network', () => {
    expect(expectValid('192.168.1.42/24')).toMatchObject({
      input: '192.168.1.42/24',
      ipAddress: '192.168.1.42',
      prefixLength: 24,
      networkAddress: '192.168.1.0',
      broadcastAddress: '192.168.1.255',
      subnetMask: '255.255.255.0',
      wildcardMask: '0.0.0.255',
      firstUsableHost: '192.168.1.1',
      lastUsableHost: '192.168.1.254',
      totalAddresses: 256,
      usableHosts: 254,
      hostRangeNote: null,
    })
  })

  it('includes binary representations for calculated addresses and masks', () => {
    expect(expectValid('192.168.1.42/24').binary).toEqual({
      ipAddress: '11000000.10101000.00000001.00101010',
      networkAddress: '11000000.10101000.00000001.00000000',
      broadcastAddress: '11000000.10101000.00000001.11111111',
      subnetMask: '11111111.11111111.11111111.00000000',
      wildcardMask: '00000000.00000000.00000000.11111111',
    })
  })

  it('calculates a /30 network with two usable hosts', () => {
    expect(expectValid('10.0.0.5/30')).toMatchObject({
      networkAddress: '10.0.0.4',
      broadcastAddress: '10.0.0.7',
      subnetMask: '255.255.255.252',
      wildcardMask: '0.0.0.3',
      firstUsableHost: '10.0.0.5',
      lastUsableHost: '10.0.0.6',
      totalAddresses: 4,
      usableHosts: 2,
      hostRangeNote: null,
    })
  })

  it('handles /31 as a point-to-point network where both addresses are usable', () => {
    expect(expectValid('203.0.113.10/31')).toMatchObject({
      networkAddress: '203.0.113.10',
      broadcastAddress: '203.0.113.11',
      firstUsableHost: '203.0.113.10',
      lastUsableHost: '203.0.113.11',
      totalAddresses: 2,
      usableHosts: 2,
      hostRangeNote: '/31 is treated as a point-to-point network; both addresses are usable.',
    })
  })

  it('handles /32 as a single host address', () => {
    expect(expectValid('203.0.113.10/32')).toMatchObject({
      networkAddress: '203.0.113.10',
      broadcastAddress: '203.0.113.10',
      subnetMask: '255.255.255.255',
      wildcardMask: '0.0.0.0',
      firstUsableHost: '203.0.113.10',
      lastUsableHost: '203.0.113.10',
      totalAddresses: 1,
      usableHosts: 1,
      hostRangeNote: '/32 identifies a single host address.',
    })
  })

  it('handles /0 as the entire IPv4 address space', () => {
    expect(expectValid('8.8.8.8/0')).toMatchObject({
      networkAddress: '0.0.0.0',
      broadcastAddress: '255.255.255.255',
      subnetMask: '0.0.0.0',
      wildcardMask: '255.255.255.255',
      firstUsableHost: '0.0.0.1',
      lastUsableHost: '255.255.255.254',
      totalAddresses: 4_294_967_296,
      usableHosts: 4_294_967_294,
      hostRangeNote: '/0 covers the entire IPv4 address space.',
    })
  })

  it('rejects invalid IPv4 input', () => {
    expect(calculateCidr('192.168.1/24')).toEqual({
      ok: false,
      errors: ['IPv4 address must contain four decimal octets from 0 to 255.'],
    })
    expect(calculateCidr('192.168.1.256/24')).toEqual({
      ok: false,
      errors: ['IPv4 address must contain four decimal octets from 0 to 255.'],
    })
  })

  it('rejects invalid prefix lengths', () => {
    expect(calculateCidr('192.168.1.1/33')).toEqual({
      ok: false,
      errors: ['Prefix length must be a whole number from 0 to 32.'],
    })
    expect(calculateCidr('192.168.1.1/-1')).toEqual({
      ok: false,
      errors: ['Prefix length must be a whole number from 0 to 32.'],
    })
  })

  it('requires CIDR notation', () => {
    expect(calculateCidr('192.168.1.1')).toEqual({
      ok: false,
      errors: ['CIDR notation must include a prefix length, e.g. /24.'],
    })
  })
})
