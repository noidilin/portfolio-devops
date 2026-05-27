import { useState } from 'react'
import './App.css'

interface CidrResult {
  networkAddress: string
  broadcastAddress: string
  subnetMask: string
  firstHost: string
  lastHost: string
  totalHosts: number
  usableHosts: number
  cidrNotation: string
}

const PLACEHOLDER: CidrResult = {
  networkAddress: '—',
  broadcastAddress: '—',
  subnetMask: '—',
  firstHost: '—',
  lastHost: '—',
  totalHosts: 0,
  usableHosts: 0,
  cidrNotation: '—',
}

function isValidCidr(input: string): boolean {
  const match = input.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,2})$/)
  if (!match) return false
  const [, a, b, c, d, prefix] = match.map(Number)
  if (a > 255 || b > 255 || c > 255 || d > 255) return false
  if (prefix < 0 || prefix > 32) return false
  return true
}

function parseCidr(input: string): CidrResult {
  const match = input.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,2})$/)!
  const [, a, b, c, d, prefix] = match.map(Number)

  const ip = (a << 24) | (b << 16) | (c << 8) | d
  const mask = prefix === 0 ? 0 : (~0 << (32 - prefix)) >>> 0
  const network = (ip & mask) >>> 0
  const broadcast = (network | ~mask) >>> 0
  const totalHosts = Math.pow(2, 32 - prefix)
  const usableHosts = prefix >= 31 ? totalHosts : totalHosts - 2

  const toIp = (n: number) =>
    [(n >>> 24) & 0xff, (n >>> 16) & 0xff, (n >>> 8) & 0xff, n & 0xff].join('.')

  return {
    networkAddress: toIp(network),
    broadcastAddress: toIp(broadcast),
    subnetMask: toIp(mask),
    firstHost: prefix >= 31 ? toIp(network) : toIp(network + 1),
    lastHost: prefix >= 31 ? toIp(broadcast) : toIp(broadcast - 1),
    totalHosts,
    usableHosts,
    cidrNotation: input,
  }
}

/* ── Blog-style shadcn Card components ── */

function Card({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card"
      className={`flex flex-col gap-2 rounded-xl border bg-card py-4 text-card-foreground shadow-sm ${className ?? ''}`}
      {...props}
    />
  )
}

function CardHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-header"
      className={`grid auto-rows-min items-start gap-1.5 px-4 ${className ?? ''}`}
      {...props}
    />
  )
}

function CardContent({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="card-content"
      className={`px-4 ${className ?? ''}`}
      {...props}
    />
  )
}

/* ── App ── */

function App() {
  const [input, setInput] = useState('')
  const [result, setResult] = useState<CidrResult | null>(null)
  const [error, setError] = useState('')
  const [dark, setDark] = useState(
    () => window.matchMedia('(prefers-color-scheme: dark)').matches,
  )

  const toggleDark = () => setDark((d) => !d)

  const handleCalculate = () => {
    const trimmed = input.trim()
    if (!trimmed) {
      setResult(null)
      setError('')
      return
    }
    if (!isValidCidr(trimmed)) {
      setError('Enter a valid CIDR, e.g. 192.168.1.0/24')
      setResult(null)
      return
    }
    setError('')
    setResult(parseCidr(trimmed))
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleCalculate()
  }

  const display = result ?? PLACEHOLDER

  return (
    <div className={dark ? 'dark' : ''}>
      <div className="min-h-screen bg-background px-4 py-12 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-3xl">
          {/* Header */}
          <div className="mb-10 text-center">
            <h1 className="text-3xl font-semibold tracking-tight text-foreground sm:text-4xl">
              CIDR Calculator
            </h1>
            <p className="mt-2 text-sm text-muted-foreground">
              Enter a CIDR block to calculate network details
            </p>
          </div>

          {/* Input row */}
          <div className="mb-8 flex gap-3">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="192.168.1.0/24"
              data-slot="input"
              className="h-9 flex-1 min-w-0 rounded-md border border-input bg-transparent px-3 py-1 font-mono text-sm shadow-xs outline-none transition-[color,box-shadow] placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 dark:bg-input/30"
            />
            <button
              type="button"
              onClick={handleCalculate}
              className="inline-flex h-9 shrink-0 items-center justify-center gap-2 rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground shadow-xs transition-colors hover:bg-primary/90"
            >
              Calculate
            </button>
          </div>

          {/* Error */}
          {error && (
            <div className="mb-6 rounded-md border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive">
              {error}
            </div>
          )}

          {/* Results Grid */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  Network Address
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.networkAddress}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  Broadcast Address
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.broadcastAddress}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  Subnet Mask
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.subnetMask}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  First Host
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.firstHost}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  Last Host
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.lastHost}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  CIDR Notation
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.cidrNotation}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  Total Addresses
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.totalHosts.toLocaleString()}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  Usable Hosts
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.usableHosts.toLocaleString()}
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Footer */}
          <div className="mt-10 flex items-center justify-between text-xs text-muted-foreground">
            <p>Placeholder UI — subnet math will be expanded in future iterations</p>
            <button
              type="button"
              onClick={toggleDark}
              className="font-mono transition-colors hover:text-accent-foreground dark:text-accent/60 dark:hover:text-accent"
            >
              [{dark ? 'light' : 'dark'}]
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
