import { useMemo, useRef, useState } from 'react'
import { calculateCidr } from './cidr'
import './App.css'

const EMPTY_VALUE = '—'
const EMPTY_PARTS: CidrParts = ['', '', '', '', '']

type CidrParts = [string, string, string, string, string]

function formatCount(value: number | null): string {
  return value === null ? EMPTY_VALUE : value.toLocaleString()
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
  const [parts, setParts] = useState<CidrParts>(EMPTY_PARTS)

  const [dark, setDark] = useState(
    () => window.matchMedia('(prefers-color-scheme: dark)').matches,
  )
  const inputRefs = useRef<Array<HTMLInputElement | null>>([])

  const toggleDark = () => setDark((d) => !d)

  const { result, errors } = useMemo(() => {
    const hasAnyInput = parts.some((part) => part !== '')
    const hasCompleteCidr = parts.every((part) => part !== '')

    if (!hasAnyInput || !hasCompleteCidr) {
      return { result: null, errors: [] }
    }

    const calculation = calculateCidr(
      `${parts[0]}.${parts[1]}.${parts[2]}.${parts[3]}/${parts[4]}`,
    )

    if (!calculation.ok) {
      return { result: null, errors: calculation.errors }
    }

    return { result: calculation.value, errors: [] }
  }, [parts])

  const handlePartChange = (index: number, rawValue: string) => {
    const maxLength = index === 4 ? 2 : 3
    const value = rawValue.replace(/\D/g, '').slice(0, maxLength)

    setParts((current) => {
      const next = [...current] as CidrParts
      next[index] = value
      return next
    })

    if (value.length === maxLength && index < 4) {
      inputRefs.current[index + 1]?.focus()
    }
  }

  const handlePartKeyDown = (
    index: number,
    event: React.KeyboardEvent<HTMLInputElement>,
  ) => {
    if (event.key === 'Backspace' && parts[index] === '' && index > 0) {
      inputRefs.current[index - 1]?.focus()
    }
  }

  const handlePaste = (event: React.ClipboardEvent<HTMLInputElement>) => {
    const pasted = event.clipboardData.getData('text').trim()
    const match = pasted.match(/^(\d+)\.(\d+)\.(\d+)\.(\d+)\/(\d+)$/)
    if (!match) return

    event.preventDefault()
    setParts([
      match[1].slice(0, 3),
      match[2].slice(0, 3),
      match[3].slice(0, 3),
      match[4].slice(0, 3),
      match[5].slice(0, 2),
    ])
    inputRefs.current[4]?.focus()
  }

  const clearInput = () => {
    setParts(EMPTY_PARTS)
    inputRefs.current[0]?.focus()
  }

  const display = {
    networkAddress: result?.networkAddress ?? EMPTY_VALUE,
    broadcastAddress: result?.broadcastAddress ?? EMPTY_VALUE,
    subnetMask: result?.subnetMask ?? EMPTY_VALUE,
    wildcardMask: result?.wildcardMask ?? EMPTY_VALUE,
    firstUsableHost: result?.firstUsableHost ?? EMPTY_VALUE,
    lastUsableHost: result?.lastUsableHost ?? EMPTY_VALUE,
    cidrNotation: result?.input ?? EMPTY_VALUE,
    prefixLength: result?.prefixLength.toString() ?? EMPTY_VALUE,
    totalAddresses: formatCount(result?.totalAddresses ?? null),
    usableHosts: formatCount(result?.usableHosts ?? null),
    binaryIpAddress: result?.binary.ipAddress ?? EMPTY_VALUE,
    binaryNetworkAddress: result?.binary.networkAddress ?? EMPTY_VALUE,
    binaryBroadcastAddress: result?.binary.broadcastAddress ?? EMPTY_VALUE,
    binarySubnetMask: result?.binary.subnetMask ?? EMPTY_VALUE,
    binaryWildcardMask: result?.binary.wildcardMask ?? EMPTY_VALUE,
  }

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
              Enter all five blocks and results update automatically
            </p>
          </div>

          {/* Input row */}
          <div className="mb-3 rounded-xl border bg-card p-4 shadow-sm">
            <div className="flex flex-wrap items-center justify-center gap-2 sm:gap-3">
              {parts.slice(0, 4).map((part, index) => (
                <div key={index} className="flex items-center gap-2 sm:gap-3">
                  <label className="sr-only" htmlFor={`octet-${index + 1}`}>
                    IPv4 octet {index + 1}
                  </label>
                  <input
                    id={`octet-${index + 1}`}
                    ref={(node) => {
                      inputRefs.current[index] = node
                    }}
                    type="text"
                    inputMode="numeric"
                    pattern="[0-9]*"
                    value={part}
                    onChange={(event) => handlePartChange(index, event.target.value)}
                    onKeyDown={(event) => handlePartKeyDown(index, event)}
                    onPaste={handlePaste}
                    placeholder={index === 0 ? '192' : index === 1 ? '168' : index === 2 ? '1' : '0'}
                    data-slot="input"
                    className="h-14 w-20 rounded-lg border border-input bg-background px-2 text-center font-mono text-2xl font-semibold text-foreground shadow-xs outline-none transition-[color,box-shadow] placeholder:text-muted-foreground/70 focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 dark:bg-input/30 sm:w-24"
                  />
                  <span className="font-mono text-3xl font-semibold text-muted-foreground">
                    {index < 3 ? '.' : '/'}
                  </span>
                </div>
              ))}

              <label className="sr-only" htmlFor="prefix-length">
                Prefix length
              </label>
              <input
                id="prefix-length"
                ref={(node) => {
                  inputRefs.current[4] = node
                }}
                type="text"
                inputMode="numeric"
                pattern="[0-9]*"
                value={parts[4]}
                onChange={(event) => handlePartChange(4, event.target.value)}
                onKeyDown={(event) => handlePartKeyDown(4, event)}
                onPaste={handlePaste}
                placeholder="24"
                data-slot="input"
                className="h-14 w-20 rounded-lg border border-input bg-background px-2 text-center font-mono text-2xl font-semibold text-foreground shadow-xs outline-none transition-[color,box-shadow] placeholder:text-muted-foreground/70 focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 dark:bg-input/30"
              />
            </div>
          </div>

          <div className="mb-8 flex items-center justify-between text-xs text-muted-foreground">
            <p>Format: octet.octet.octet.octet/prefix</p>
            <button
              type="button"
              onClick={clearInput}
              className="font-mono transition-colors hover:text-accent-foreground dark:hover:text-accent"
            >
              [clear]
            </button>
          </div>

          {/* Error */}
          {errors.length > 0 && (
            <div className="mb-6 rounded-md border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive">
              <ul className="list-disc pl-5">
                {errors.map((message) => (
                  <li key={message}>{message}</li>
                ))}
              </ul>
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
                  Wildcard Mask
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.wildcardMask}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  First Usable Host
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.firstUsableHost}
                </p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                  Last Usable Host
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.lastUsableHost}
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
                  Prefix Length
                </span>
              </CardHeader>
              <CardContent>
                <p className="font-mono text-base font-semibold text-card-foreground">
                  {display.prefixLength}
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
                  {display.totalAddresses}
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
                  {display.usableHosts}
                </p>
              </CardContent>
            </Card>
          </div>

          {result?.hostRangeNote && (
            <div className="mt-4 rounded-md border border-accent/70 bg-accent/30 px-4 py-3 text-sm text-accent-foreground">
              {result.hostRangeNote}
            </div>
          )}

          <div className="mt-6">
            <h2 className="mb-3 font-mono text-xs uppercase tracking-wider text-muted-foreground">
              Binary Representations
            </h2>
            <div className="grid grid-cols-1 gap-4">
              <Card>
                <CardHeader>
                  <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                    Input IP
                  </span>
                </CardHeader>
                <CardContent>
                  <p className="break-all font-mono text-sm font-semibold text-card-foreground">
                    {display.binaryIpAddress}
                  </p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                    Network Address
                  </span>
                </CardHeader>
                <CardContent>
                  <p className="break-all font-mono text-sm font-semibold text-card-foreground">
                    {display.binaryNetworkAddress}
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
                  <p className="break-all font-mono text-sm font-semibold text-card-foreground">
                    {display.binaryBroadcastAddress}
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
                  <p className="break-all font-mono text-sm font-semibold text-card-foreground">
                    {display.binarySubnetMask}
                  </p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <span className="font-mono text-xs uppercase tracking-wider text-muted-foreground">
                    Wildcard Mask
                  </span>
                </CardHeader>
                <CardContent>
                  <p className="break-all font-mono text-sm font-semibold text-card-foreground">
                    {display.binaryWildcardMask}
                  </p>
                </CardContent>
              </Card>
            </div>
          </div>

          {/* Footer */}
          <div className="mt-10 flex items-center justify-between text-xs text-muted-foreground">
            <p>Fully client-side IPv4 CIDR calculator</p>
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
