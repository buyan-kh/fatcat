export type VerificationInput = {
  expected: string
  observed: string
  confidence: number
}

export type VerificationResult = VerificationInput & {
  verified: boolean
  difference: string
}

export function verifyAction(input: VerificationInput): VerificationResult {
  const expected = input.expected.trim().toLowerCase()
  const observed = input.observed.trim().toLowerCase()
  const matches = expected.length > 0 && expected === observed
  return {
    ...input,
    verified: matches && input.confidence >= 0.8,
    difference: matches ? '' : `Expected “${input.expected}” but observed “${input.observed}”.`,
  }
}

