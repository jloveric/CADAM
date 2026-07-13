/// <reference types="vite/client" />

// Pull in TanStack Start's route `server.handlers` module augmentation
// (`@tanstack/start-client-core/serverRoute`). Without this, `tsc` only sees
// `@tanstack/react-router` and rejects every API route's `server:` block.
import type {} from '@tanstack/react-start';
