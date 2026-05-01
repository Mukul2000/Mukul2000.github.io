---
layout: page
title: "A Second Brain With \"Teeth\""
description: ""
---

## **Part 1: Introduction**

### The "Second Brain"

Second Brain philosophy is basically offloading your cognitive load to a digital system.

We use it to store everything: study notes, todos, obscure things and so on. You name it, and you should store it in the vault. The idea is to free up your brain from storing information. You can always look up the vault for something you need.


### The Project

Over the last few months, I've been building a custom Retrieval-Augmented Generation (RAG) pipeline specifically tuned for my personal notes. I'll shortly come to the why of building it.

 > In summary: It's basically a worse version of notebookLM :`)

## **Part 2: The Problem**
 
### Why does it need "Teeth"

I am usually very selective and proper what goes into the second brain. Fast forward a couple of years I have about ~600 different notes and a graph of nodes I cannot make sense of. I am partly to blame for not organizing it earlier, but meh it's too late now. It looks beautiful, but it’s becoming a "write-only" memory. The built-in keyword search is fine if I remember the exact term used, and if not, I'll probably never find it.

As you start using it for more things, you realise it leaves a lot to be desired, especially with all the AI advancements you don't need to go through that toil.
- Why'd you want to read through a 1000 line note for just one thing?
- Maybe you spotted something that doesn't make sense. You will probably need to gather context from previous sections or neighbouring notes to see if it's right or wrong.
- And even sometimes, you just need to go through multiple notes in an exploratory manner, you want to have a conversation about it.
- The manual effort of organizing things is a lot. While I do have a basic level of organization into folders, and a good use of notes linking feature provided by Obsidian, it still isn't enough for finding things. Any other organization method would probably lead to changes across the board, not to mention the effort of maintaining it.

## **Part 3: The Solution**

With all the AI rage, you must've heard of embeddings. That's precisely what we're gonna use. Embeddings are similar to keyword search but are better in a sense that it actually understands the semantics (meaning) of the text.

A Retrieval Augmented Generation setup will have the documents broken up into embeddings in a vector database. And whenever you need things you'll query the database.

![Architecture](/assets/images/rag-on-notes/arch.png){: width="960"}

This is how the (ideal) system will come together. We'll need the following things:
1. An LLM which the user (me) will interact with.
2. An MCP server which we will use to expose a tool for LLM which can search notes
3. A vector database for storing our embeddings
4. The Embedding System - This will do the heavy lifting of converting my notes to embeddings, storing them in the vector database and taking care of updates.
  - 4.1 Embedding model
  - 4.2 Embedding Engine - How do you want to breakup and chunk your notes
  - 4.3 The file system


  The stack looks something like this:
- **LLM:** I will not be choosy here, any good one will do. I chose to use gemini CLI which has easy support for MCP server integration.
- **MCP**: I used python fastMCP to quickly build an MCP server for this.
- **Vector Database:** There's lot of vector databases on the market. Some are native and some are relational databases with a new vector datatype. I know I know it sounds a lot cooler to use the latest vector databases and that's what I did. But for reasons I'll come to later I actually found it easier to use postgres with a vector extension.
- **Embedding System:** Responsible for chunking and embedding data in the vector DB.
- **Embedding Model:** My requirements of an embedding model were not fancy, just needed a good one. I had no need for multi-lingual, and size for the most part wasn't a big deal for me. I own a beefy GPU, I can run most embedding models without thinking twice.

### Embedding Engine
This is the foundation of the whole system. Performance in this section determines the performance of the system.

#### Chunking Strategy
All my notes are in markdown. And, markdown follows a specific structure (mostly). This post you're reading is written in markdown!
So the structure is you have headings, and inside you have subheadings forming a tree like structure.

![Markdown structure](/assets/images/rag-on-notes/markdown_structure.png){: width="360"}

The regular way of chunking unstructured data is you take X number of characters and you embed them. Then you slide the window so that you have a certain overlap (to preserve context between adjacent chunks) and embed that.

With markdown, we can take advantage of the structure. Each heading will have content and we'll add a 'breadcrumb' trail inside each heading to hopefully allow richer embeddings.

In the above example, when encoding 'Sub-heading of 2' we'll encode a breadcrumb trail like so: `Top Level Heading > Sub-heading 2 > Subheading of 2`.
The final content that we'll embed will look something like this: `<breadcrumb trail> <page_content>`

This helps the embedding model know that it should probably keep this embedding somewhere close to the embedding of top level heading. So now each file gets broken up into chunks, which are all linked to each other in some manner and are turned into embeddings then stored in the vector database.

Obsidian provides a graph view of notes which tells you what all notes this is linked to. We can add the names of those neighbouring notes as well to enrich the embeddings even more.

#### Handling Updates

Adding new files is simple, but what about when a file is updated? There's probably a few ways to do this but I went the easiest way, if a file is updated, I will simply re-embed it. I can get away with this due to the small scale of the project. You'll likely want a more clever strategy when doing something like this in a production system.

I store the following data for each chunk:
```
metadata = {
	file_path: ~/ok.md --> needed for recon job updates
	chunk_index: 0 / 1 / 2
	file_hash: md5 hash of file content to check for updates
	embedding_model: MiniLM / CLIP etc
	created_at: <timestamp>
	updated_at: <timestamp>
},
page_content = <actual raw chunk content>
vector = <actual embedding>
```

The interesting part here is `file_hash`, if the file content hasn't changed we can just skip embedding the thing altogether.
If the file indeed has changed, the hash has changed, then we just delete ALL chunks belonging to that file and re-embed that file again. This is neat, and why I favored postgres over the newer vector databases. I can do the deletions in one transaction preventing any zombie chunks lying around.

### The Metrics

Monitoring is divided into 3 different parts:
1. **Retrieval Metrics:** How well your vector database and embedding model are performing. How relevant are the fetched results?
2. **Generation Metrics:** Is the LLM hallucinating? Is the LLM output actually rooted in the context? 
3. **Infra and Application Metrics:** Latency, TTFT, time between tokens etc. But you mostly need to track this for user experience if you're serving a large number of users. I am just serving me and I am totally fine to wait a bit for the LLM to output the response.

#### Generation Metrics

These are often called the "RAG Triad"

- **Faithfulness (Groundedness):** Can every claim in the answer be traced back to the retrieved chunks? (Score 0–1). If this is low, the model is **hallucinating**.
- **Answer Relevancy:** Does the answer actually address the user's prompt? Sometimes a model stays "faithful" to the text but fails to answer the actual question.
- **Context Relevancy:** How much of the retrieved context was actually used? If you retrieve 5 chunks but only use 1, you're wasting tokens and increasing latency.

#### Retrieval Metrics
These measure the performance of the vector database and the embeddings. How relevant are the fetched results? 
There's a world of metrics out there, but I decided to use the following 2:

- **Context precision**: Out of all the documents retrieved, what percentage is relevant to the query?  While we usually think of precision as "how many results were relevant?", Ragas takes it a step further by measuring Rank-Aware Precision. It’s not just about finding the right note; it’s about ensuring the most relevant chunks are at the top of the pile.
- **Context recall**: Out of all the documents that are relevant to the query, what percentage is retrieved?


1. **Context Recall (The "Did I find it?" Metric)**
This measures the completeness of the search. If the answer to my question exists in a specific note about B+ Trees, did pgvector actually pull that note into the top results?

Calculation:

$$\text{Context Recall} = \frac{|\text{Attributable Sentences in Ground Truth}|}{|\text{Total Sentences in Ground Truth}|}$$

If the Recall is low, something is wrong with how I am embedding things, the model itself could be weak or there is some other issue in the system


2. **Context Precision (The "Is there too much noise?" Metric)**

This measures the quality of the ranking. It’s not enough to find the right note; it should be at the very top of the list. If I retrieve 5 chunks but the only relevant one is at the bottom (rank 5), my Precision is lower.


#### Collecting the Metrics via "Golden Dataset"

Collecting these metrics starts with building a "Golden Dataset". A Golden Dataset is a collection of "Ground Truth" triplets. Each entry consists of:
- **The Ground Truth:** Some content from my notes.
- **The Question:** A question derived from ground truth by the generator LLM.
- **The Context:** The chunks returned by the database given the question.

Generating this manually for 300+ notes is soul-crushing work. Instead, I used Ragas to automate the process. Ragas can create simple fact-based, complex, multi-context, and reasoning-based questions that actually stress-test the system.

**The Execution: LLM-as-a-Judge**

To calculate these, I used Gemini 2.5 Pro as a "Judge" (Very expensive stuff). Using a more powerful model as a judge results in better evaluation because it can make sense of things better (like how you'd want your test grader to be smarter than you). Your generator might have outputted the right thing, but a weak judge might just give it a negative score. The process looks like this:

1. The inputs: Ground truth (ideal answer) and the retrieve context.
2. The Judge LLM breaks down the ground truth answer into individual claims and asks "Can this specific claim be found in the retrieved chunks"
3. For context recall the answer is ratio of attributed / total.

Context precision and other metrics are similarly calculated.

 > Tip: When building the golden dataset, start small and save your golden dataset somewhere (for example don't overwrite it), I had to pay 2-3x in API fee because I deleted it and was being careless with initial experimentation :(.

A rough evaluation would look like this:
```python
# 1. Define the metric 
metric = FaithfulnessMetric(threshold=0.7) 
# 2. Create a test case from your actual RAG 
run test_case = LLMTestCase( input="How do I change my Pi's WiFi?", actual_output="You can change it by editing the wpa_supplicant.conf file.", retrieval_context=["To change wifi on a headless Pi, edit wpa_supplicant.conf on the SD card."] ) 

# 3. Measure 
metric.measure(test_case) print(f"Score: {metric.score}") # 0 to 1 
print(f"Reason: {metric.reason}") # Why the judge gave that score
```

-------------------

And with this, we're done with the problem of setting up monitoring. Everytime I change something in my embedding system, I can quickly run this evaluator to see if it actually got better (or worse).

## Results



## **Conclusion**

I am very happy to see myself actually and actively using a side project for once, not something that's one and done and forgotten.

Tackling this like a software engineering project at work honestly did help me overcome a lot of possible gotchas. I learnt a lot as I worked through the various challenges here too. I baked in evaluation and monitoring from Day 1, and they helped me a lot in trying to understand if the changes to the embedding system were actually positive or negative.

While building this was fun. I do have a few more ideas on the roadmap. 
- Agentic Workflows: Integrating the Obsidian CLI so the system doesn't just answer questions but can actually create new notes or update existing ones based on my conversations.
- Local LLMs: Moving the "Judge" and the "Generator" to a local Ollama instance to make the system 100% private and internet-independent. There's nothing I'd love more than to build a homelab which can run all my models locally. But for now my gaming PC will have to do.

I hope I actually taught you something or atleast you found it fun. Bye :)
