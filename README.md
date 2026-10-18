# Recreated Early Strategy Experiments

My original early Python files are no longer available. These two small files are **later recreations**, based on what I remember experimenting with when I first learned about quantitative trading. I recreated them while preparing this portfolio, with AI assistance, so they should not be read as preserved copies of my original freshman/sophomore-year code.

They show the basic ideas I remember working with: momentum by comparing a newer price with an earlier price, and mean reversion by comparing the current price with a recent average. The code is intentionally simple because the purpose is to show the kind of starting point that eventually developed into QuantQuest.

The current app implements these same ideas in TypeScript in `src/engine.ts`, where they are part of a shared strategy engine used by the React Native app. ChatGPT and Cursor substantially assisted the transition into the mobile-app implementation, along with debugging, integration, and technologies that were new to me.
