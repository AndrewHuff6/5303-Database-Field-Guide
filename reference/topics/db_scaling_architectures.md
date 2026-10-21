# Database Scaling Architectures
### Replication, Sharding, Partitioning, and Distributed Database Systems

**Advanced Database Systems — Student Handout**

---

## 1. Introduction: When One Database Server Isn't Enough

Imagine a database containing 10,000 customer records. Almost any modern relational database can handle that workload comfortably.

Now imagine the same database supporting:

- 100 million customers.
- Several billion transactions.
- Applications operating across multiple continents.
- Thousands of simultaneous queries.
- Continuous data ingestion.
- Requirements for minimal downtime.

The problem is no longer simply storing and retrieving data. We must also consider **capacity, throughput, latency, availability, fault tolerance, and consistency**.

Several architectural techniques help address these challenges:

1. **Replication:** Maintaining multiple copies of data.
2. **Horizontal partitioning (sharding):** Dividing rows or documents across data partitions, potentially on different servers.
3. **Vertical partitioning:** Dividing columns, attributes, or functional groups of data.
4. **Distributed databases:** Coordinating data storage or processing across multiple machines.

These techniques overlap, but they solve different problems.

The fundamental distinction is:

> **Replication copies data. Partitioning divides data. Distribution coordinates data or computation across machines.**

A database system may employ one, two, or all three techniques.

---

## 2. Understanding Database Scaling

Before examining individual architectures, distinguish two fundamental approaches to scaling.

### 2.1 Vertical scaling — Scale Up

Vertical scaling increases the resources available to an existing server.

For example, upgrading a database server from:

| Resource |   Before |     After |
| -------- | -------: | --------: |
| CPU      |  8 cores |  32 cores |
| RAM      |    32 GB |    256 GB |
| Storage  | 1 TB SSD | 8 TB NVMe |
| Network  |   1 Gbps |   25 Gbps |

The database remains on one server, but the server becomes more powerful.

**Advantages:** Minimal architectural changes, simpler administration, and no new distributed coordination requirements.

**Limitations:** Hardware has practical limits, high-end machines can be expensive, and a single server may remain a single point of failure.

### 2.2 Horizontal scaling — Scale Out

Horizontal scaling adds more machines rather than increasing the size of one machine.

```text
               APPLICATION
                    |
          +---------+---------+
          |         |         |
       Server A  Server B  Server C
```

However, adding servers does not automatically increase database capacity.

The servers must have useful work to perform.

For example, adding three replicas may increase read capacity but leave write capacity constrained by the original database's write-processing architecture.

Distributing different portions of the data across three shards may increase write capacity, but it also introduces routing and coordination challenges.

**Horizontal scaling is an architectural strategy, not simply a hardware purchase.**

### 2.3 What exactly are we scaling?

Database performance has several dimensions.

| Dimension        | Question                                                  |
| ---------------- | --------------------------------------------------------- |
| Storage capacity | How much data can we retain?                              |
| Read throughput  | How many queries can we process per second?               |
| Write throughput | How many inserts and updates can we sustain?              |
| Latency          | How long does an individual operation take?               |
| Availability     | Can the system continue serving requests during failures? |
| Geographic reach | Can users access data efficiently from different regions? |

An architecture that improves one dimension may worsen another.

For example, distributing data across continents can improve regional access but make globally coordinated transactions slower.

**Scaling requires identifying the bottleneck before choosing a solution.**

---

## 3. Replication: Multiple Copies of the Same Data

Replication maintains copies of data on multiple database instances.

The primary motivations are availability, fault tolerance, disaster recovery, and sometimes read scalability.

### 3.1 Primary–replica replication

Consider a PostgreSQL deployment:

```text
                   APPLICATION
                        |
                        v
                 +-------------+
                 |   PRIMARY   |
                 | PostgreSQL  |
                 +-------------+
                        |
               Replication Stream
                        |
              +---------+---------+
              |                   |
              v                   v
       +-------------+     +-------------+
       |  REPLICA A  |     |  REPLICA B  |
       | PostgreSQL  |     | PostgreSQL  |
       +-------------+     +-------------+
```

The primary processes writes. Replicas receive changes and maintain copies of the database.

Depending on the configuration, applications may also send read queries to replicas.

For example:

```sql
INSERT INTO orders (customer_id, total)
VALUES (42, 199.95);
```

The write goes to the primary.

Later, a reporting query might execute against a replica:

```sql
SELECT customer_id, SUM(total)
FROM orders
GROUP BY customer_id;
```

This can reduce read pressure on the primary.

However, a replica may temporarily lag behind the primary.

### 3.2 Physical versus logical replication

Database systems can replicate information at different levels.

**Physical replication** reproduces changes to the database's physical storage representation.

PostgreSQL commonly uses Write-Ahead Log (WAL) streaming for physical replication.

**Logical replication** communicates higher-level data changes, such as inserted, updated, or deleted rows.

PostgreSQL supports both approaches.

Physical replication is useful for maintaining closely synchronized copies of an entire database cluster.

Logical replication offers more flexibility, including selective table replication and certain migration scenarios.

These mechanisms are not interchangeable in every situation.

### 3.3 Synchronous versus asynchronous replication

Replication can differ in when the database acknowledges a write.

**Asynchronous replication:**

```text
Client        Primary          Replica
  |              |                |
  |--- INSERT -->|                |
  |              |                |
  |<--- OK ------|                |
  |              |--- Changes --->|
  |              |                |
```

The primary acknowledges the write without waiting for the replica to confirm it.

Advantages include lower write latency and less dependence on replica response time.

The tradeoff is that an acknowledged write may not yet exist on the replica. If the primary fails before changes are replicated, recent data can be lost during failover.

**Synchronous replication:**

```text
Client        Primary          Replica
  |              |                |
  |--- INSERT -->|                |
  |              |--- Changes --->|
  |              |<--- ACK -------|
  |<--- OK ------|                |
```

The primary waits for a configured replication acknowledgment before reporting success.

This can improve durability guarantees, but it increases write latency and can reduce availability when required replicas cannot respond.

The exact guarantee depends on the database, its configuration, and what the acknowledgment means. For example, receiving a log record, durably writing it, and applying it so that queries can see it are different milestones.

### 3.4 Replication in MongoDB

MongoDB commonly uses **replica sets**.

A replica set contains one primary and one or more secondary members.

```text
                MongoDB Replica Set
                        |
              +-------------------+
              |      PRIMARY      |
              |    Read / Write   |
              +-------------------+
                        |
                      Oplog
                        |
              +---------+---------+
              |                   |
              v                   v
        SECONDARY A         SECONDARY B
```

The primary records operations in an oplog. Secondary members replicate and apply those operations.

If the primary becomes unavailable, eligible members can participate in an election to select a new primary.

This is an important difference from a basic PostgreSQL streaming-replication deployment: MongoDB replica sets include an integrated election mechanism, whereas PostgreSQL commonly relies on additional failover-management software.

MongoDB also supports configurable write concerns and read concerns.

A write acknowledged by a majority of voting data-bearing members has different durability properties from a write acknowledged only by the primary.

### 3.5 Replication in ClickHouse

ClickHouse commonly uses the `ReplicatedMergeTree` table engine.

Instead of replicating a conventional row-oriented transaction log, replicas coordinate and exchange immutable data parts.

ClickHouse Keeper maintains coordination metadata.

```text
               ClickHouse Keeper
                       |
             Replication Metadata
                       |
             +---------+---------+
             |                   |
             v                   v
       ClickHouse A         ClickHouse B
       Data Parts           Data Parts
```

This approach is well suited to ClickHouse's analytical storage architecture.

Replication is asynchronous by default. Quorum insert settings can provide stronger acknowledgment requirements for replicated writes.

Unlike MongoDB's conventional replica-set model, ClickHouse replicated tables do not require one permanently designated primary for ordinary inserts.

### 3.6 Replication is not backup

A replica is not automatically a backup.

Consider:

```sql
DELETE FROM customers;
```

If this command executes successfully on the primary, replication may faithfully reproduce the deletion on every replica.

Likewise, application bugs and certain forms of data corruption can propagate.

Replication primarily addresses availability and redundancy.

Backups address recovery from unwanted changes, corruption, and historical data loss.

**A production system often needs both replication and backups.**

---

## 4. Horizontal Partitioning and Sharding

Replication stores additional copies of data.

Sharding distributes different subsets of data.

Suppose a database contains 300 million customer records.

Instead of storing all customers on one server, we might divide them across three servers.

```text
                    CUSTOMERS
                  300M records
                       |
          +------------+------------+
          |            |            |
          v            v            v
       SHARD A       SHARD B       SHARD C
       100M rows     100M rows     100M rows
```

Each shard stores a different subset of the logical dataset.

Together, the shards represent the complete collection.

### 4.1 Horizontal partitioning versus sharding

The terms are closely related but not identical.

**Horizontal partitioning** divides a table into groups of rows.

Those partitions may all remain on one database server.

**Sharding** generally refers to distributing horizontal partitions across separate database instances or nodes.

For example, PostgreSQL supports native table partitioning:

```sql
CREATE TABLE orders (
    order_id BIGINT,
    order_date DATE NOT NULL,
    amount NUMERIC(10,2)
)
PARTITION BY RANGE (order_date);
```

We can then create partitions:

```sql
CREATE TABLE orders_2025
PARTITION OF orders
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

CREATE TABLE orders_2026
PARTITION OF orders
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
```

These partitions can reside within one PostgreSQL instance.

That is partitioning, but not necessarily distributed sharding.

To distribute PostgreSQL data across multiple servers, an application can implement sharding itself or use technology such as Citus.

### 4.2 Choosing a shard key

The shard key determines where records are stored.

Consider a customer collection:

```json
{
  "customer_id": 1042,
  "name": "Alice",
  "region": "Texas",
  "total_spent": 1250.00
}
```

Several sharding strategies are possible.

**Range-based sharding** assigns ranges of keys to different shards.

```text
Customer IDs

       1 - 1000000    -> Shard A
 1000001 - 2000000    -> Shard B
 2000001 - 3000000    -> Shard C
```

This makes some range queries efficient.

However, sequentially increasing IDs can concentrate new writes on the shard holding the highest range.

**Hash-based sharding** distributes records using a hash of a key.

Conceptually:

```python
shard = hash(customer_id) % number_of_shards
```

This can distribute records more evenly when the hash is appropriate.

However, the simple modulo approach creates substantial redistribution work when the shard count changes. Real systems commonly use more sophisticated partition maps, virtual partitions, or consistent-hashing approaches.

**Geographic sharding** assigns records according to location.

```text
North America -> Shard A
Europe        -> Shard B
Asia          -> Shard C
```

This may improve regional latency or help meet data-residency requirements.

But a query spanning all regions may need to contact every shard.

### 4.3 The problem of cross-shard queries

Suppose orders are sharded by customer ID.

This query may be easy to route:

```sql
SELECT *
FROM orders
WHERE customer_id = 1042;
```

The database can identify the appropriate shard if it knows how customer IDs are mapped.

Now consider:

```sql
SELECT SUM(amount)
FROM orders;
```

This query requires information from every shard.

A distributed query engine may execute:

```text
                  SUM(amount)
                      |
               Query Coordinator
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
       Shard A     Shard B     Shard C
       SUM(A)      SUM(B)      SUM(C)
          |           |           |
          +-----------+-----------+
                      |
               SUM(A+B+C)
```

This is a distributed aggregation.

Some aggregations are easy to combine across shards. Others require substantial data movement.

For example, distributed joins can become expensive when matching rows reside on different machines.

**The shard key is one of the most consequential architectural decisions in a distributed database.**

---

## 5. Vertical Partitioning: Dividing Columns or Data Domains

Horizontal partitioning divides rows.

Vertical partitioning divides columns or attributes.

Consider a customer table:

| customer_id | name | email | address | profile_photo | biography |
| ----------- | ---- | ----- | ------- | ------------- | --------- |

Most queries may need only:

```text
customer_id
name
email
```

But the table also contains large profile photographs and biographies.

We could divide it into two tables.

**Customer information:**

| customer_id | name | email |
| ----------- | ---- | ----- |

**Customer profiles:**

| customer_id | address | profile_photo | biography |
| ----------- | ------- | ------------- | --------- |

The common `customer_id` allows us to reconstruct the original information.

```text
                 CUSTOMERS
                     |
            Vertical Partition
                     |
           +---------+---------+
           |                   |
           v                   v
    Customer_Core       Customer_Profile
    ---------------     ----------------
    customer_id         customer_id
    name                address
    email               profile_photo
                        biography
```

### 5.1 Why vertically partition data?

Potential advantages include reducing the amount of data accessed by common queries, separating frequently accessed attributes from rarely accessed attributes, and allowing different storage or security policies.

However, vertical partitioning introduces additional joins when applications need the complete record.

It can also complicate transactions if the partitions reside on different servers.

### 5.2 Vertical partitioning versus column-oriented storage

These concepts are frequently confused.

**Vertical partitioning** separates columns into distinct logical or physical partitions.

**Column-oriented storage** organizes values by column internally.

DuckDB and ClickHouse use column-oriented storage, but that does not mean every table is vertically partitioned into separate application-visible tables.

A column-oriented database can still expose a single logical table containing dozens of columns.

This distinction is especially important when comparing PostgreSQL, DuckDB, and ClickHouse.

### 5.3 Vertical sharding

Vertical partitioning becomes a form of vertical distribution when the separated data resides on different database servers.

For example:

```text
                 APPLICATION
                      |
          +-----------+-----------+
          |                       |
          v                       v
     Customer DB              Orders DB
     PostgreSQL               PostgreSQL
          |                       |
     Customers                 Orders
     Profiles                  Payments
```

This architecture might divide data by business function rather than individual columns.

Some authors call this vertical sharding or functional sharding.

Terminology varies, so a system design should state precisely whether it divides columns, tables, business domains, or entire services.

---

## 6. Distributed Databases: Coordinating Multiple Machines

A distributed database operates across multiple computers while providing coordinated access to data.

The defining feature is not merely having several servers.

It is the coordination required to make those servers function as part of a database system.

A distributed architecture may involve replication, sharding, distributed query execution, distributed transactions, or several of these together.

### 6.1 A replicated distributed database

```text
             Application
                  |
          +-------+-------+
          |               |
          v               v
       Replica A       Replica B
       Full Data       Full Data
```

Both nodes store substantially the same data.

The primary purpose is redundancy or read scalability.

### 6.2 A sharded distributed database

```text
             Application
                  |
             Coordinator
                  |
          +-------+-------+
          |               |
          v               v
        Shard A         Shard B
       Data 1-50       Data 51-100
```

Each node stores a different subset.

The primary purpose is distributing storage and processing workloads.

### 6.3 A replicated and sharded distributed database

A more realistic large-scale architecture combines both:

```text
                    APPLICATION
                         |
                    QUERY ROUTER
                         |
             +-----------+-----------+
             |                       |
           SHARD A                 SHARD B
             |                       |
        +----+----+             +----+----+
        |         |             |         |
        v         v             v         v
      A-1       A-2           B-1       B-2
    Replica   Replica       Replica   Replica
```

Each shard contains different data.

Each replica within a shard maintains a copy of that shard's data.

This architecture can provide both capacity scaling and fault tolerance.

But it also introduces more complex failure scenarios.

What happens if one replica fails? What happens if an entire shard becomes unavailable? What happens if the network separates the cluster into groups that cannot communicate?

These questions lead directly to distributed systems theory.

---

## 7. Consistency, Availability, and the CAP Theorem

Distributed databases must cope with network failures.

A particularly important failure is a **network partition**, where nodes remain operational but cannot communicate reliably.

The CAP theorem describes a fundamental tradeoff under network partition conditions.

Its three terms are:

- **Consistency:** Every read observes the most recent successful write, or the operation fails. This refers to linearizability, not the `C` in ACID.
- **Availability:** Every request to a non-failing node receives a response, though the response need not contain the latest data.
- **Partition tolerance:** The system continues operating despite network communication failures between groups of nodes.

When a network partition occurs, a distributed system cannot guarantee both CAP consistency and CAP availability for every operation.

It must choose how to behave.

### 7.1 Prioritizing consistency

Suppose two nodes cannot communicate.

If a node cannot establish that it is authorized to accept a write, it may reject or delay the operation.

This sacrifices availability for that operation but avoids conflicting successful writes.

### 7.2 Prioritizing availability

Alternatively, both isolated nodes might continue accepting writes.

This allows operations to succeed during the partition.

However, the system must later reconcile potentially conflicting versions of the data.

### 7.3 What CAP does not mean

CAP does **not** mean that databases permanently choose only two of three desirable properties.

It describes guarantees during network partitions under specific definitions of consistency and availability.

It also does not determine ordinary query performance, transaction isolation levels, or replication lag.

Systems frequently offer configurable consistency and durability behavior.

For example, MongoDB supports different read and write concerns, allowing applications to make tradeoffs between latency, consistency, and durability.

**CAP is a framework for reasoning about failures, not a universal database ranking system.**

---

## 8. Comparing Real Database Systems

The following systems illustrate different approaches to scaling.

| Database    | Replication                                 | Sharding                                                       | Typical architecture              |
| ----------- | ------------------------------------------- | -------------------------------------------------------------- | --------------------------------- |
| PostgreSQL  | Native physical and logical replication     | External/application-level solutions; extensions such as Citus | General-purpose relational server |
| MySQL       | Native replication and Group Replication    | Application-level or specialized clustered solutions           | General-purpose relational server |
| MongoDB     | Replica sets                                | Native sharded clusters                                        | Distributed document database     |
| ClickHouse  | ReplicatedMergeTree                         | Native distributed tables and sharding                         | Distributed analytical database   |
| Cassandra   | Replication across nodes                    | Native token-based partitioning                                | Distributed wide-column database  |
| Redis       | Primary–replica replication                 | Redis Cluster                                                  | In-memory key-value database      |
| CockroachDB | Integrated replication                      | Automatic range distribution                                   | Distributed SQL database          |
| DuckDB      | Not a native multi-node replicated database | Not a native distributed server                                | Embedded analytical database      |
| SQLite      | No built-in multi-node replication protocol | No native distributed sharding                                 | Embedded relational database      |

The differences become clearer when examining individual systems.

### 8.1 PostgreSQL: Strong single-server foundations

PostgreSQL is an excellent general-purpose relational database.

It supports sophisticated indexing, transactions, query optimization, partitioning, and replication.

However, a standard PostgreSQL installation does not automatically become a horizontally sharded distributed database.

Additional infrastructure is generally required.

This makes PostgreSQL a useful baseline for comparing traditional relational architectures with distributed database systems.

### 8.2 MongoDB: Replication and sharding as separate building blocks

MongoDB provides native support for both replica sets and sharded clusters.

In a sharded deployment, each shard commonly operates as a replica set.

MongoDB uses `mongos` routers and configuration servers to coordinate access to sharded data.

```text
                   APPLICATION
                        |
                        v
                   mongos Router
                        |
             +----------+----------+
             |                     |
             v                     v
          Shard A               Shard B
        Replica Set           Replica Set
```

This makes MongoDB particularly useful for demonstrating how sharding and replication work together.

### 8.3 ClickHouse: Distributed analytical processing

ClickHouse emphasizes fast analytical queries.

Its column-oriented storage, compression, data skipping, and vectorized execution help it process large analytical datasets efficiently.

A distributed ClickHouse deployment can combine shards and replicas.

A distributed query may execute partial aggregations on several shards and merge the results.

ClickHouse therefore provides a useful contrast with MongoDB: both support distributed architectures, but their storage engines and intended workloads differ significantly.

### 8.4 Cassandra: Distribution as a foundational assumption

Apache Cassandra is designed around distributed storage.

Data is partitioned across nodes using token ranges, and replicas are placed according to a replication strategy.

Its architecture avoids relying on a single permanently designated primary for all writes.

Cassandra also provides configurable consistency levels for reads and writes.

This makes it an excellent counterexample to traditional primary–replica database architectures.

### 8.5 CockroachDB: Distributed SQL

CockroachDB provides a relational SQL interface while distributing data across a cluster.

It automatically divides data into ranges and maintains replicated copies using consensus mechanisms.

Its goal is to preserve familiar SQL and transactional behavior while supporting distributed storage and failure recovery.

The tradeoff is additional coordination, especially for transactions involving data on multiple nodes.

### 8.6 DuckDB and SQLite: Distribution is not always necessary

DuckDB and SQLite provide an important counterpoint to the assumption that modern databases must be distributed.

SQLite is an embedded transactional database.

DuckDB is an embedded analytical database.

Both can provide excellent performance without a database server cluster.

For many applications, the simplicity of a single-process or single-machine database is an advantage rather than a limitation.

A distributed architecture introduces network latency, coordination overhead, operational complexity, and additional failure modes.

**The best scaling architecture may be the one that avoids distribution until it is genuinely needed.**

---

## 9. Replication and Sharding: What Happens During Failure?

Consider a cluster with two shards and two replicas per shard.

```text
                    APPLICATION
                         |
                      ROUTER
                         |
             +-----------+-----------+
             |                       |
           SHARD A                 SHARD B
             |                       |
          +--+--+                 +--+--+
          |     |                 |     |
         A1     A2               B1     B2
```

### Scenario A: Replica A1 fails

Replica A2 may continue serving requests for Shard A.

Whether writes continue depends on the database's consistency rules and the availability of required quorums or coordination services.

### Scenario B: Both A1 and A2 fail

Shard A becomes unavailable.

Shard B may remain operational, but requests requiring Shard A's data cannot be completed normally.

### Scenario C: The network partitions

Suppose A1 and A2 cannot communicate.

The database must determine whether either replica can safely accept writes.

Some systems use leader elections or quorum-based protocols.

Others use different consistency and reconciliation mechanisms.

### Scenario D: A shard becomes overloaded

Replication may help distribute read traffic.

However, if the shard's primary bottleneck is write throughput or storage capacity, adding replicas may not solve the problem.

The shard may need to be split or its data redistributed.

**Replication addresses redundancy. Sharding addresses distribution of data. Neither automatically solves every scaling problem.**

---

## 10. The Hidden Costs of Distribution

Distributed databases provide substantial benefits, but those benefits are not free.

### Network latency

A local memory access is vastly faster than communicating with another server over a network.

Queries involving multiple nodes may spend significant time waiting for communication.

### Distributed joins

When related records reside on different shards, a join may require transferring data between machines.

This can make shard-key selection and data locality extremely important.

### Distributed transactions

Transactions spanning multiple nodes require additional coordination.

Depending on the system, this may involve consensus protocols, distributed commit mechanisms, or other coordination techniques.

### Rebalancing

When adding or removing nodes, the system may need to move substantial amounts of data.

Rebalancing consumes disk bandwidth, network capacity, CPU, and memory.

### Operational complexity

Distributed systems require monitoring for node failures, replication lag, network partitions, uneven shard utilization, and coordination-service health.

A single database server may be easier to operate, troubleshoot, and secure.

---

## 11. Choosing an Architecture

Consider the following scenarios.

| Requirement                                | Architecture worth considering             |
| ------------------------------------------ | ------------------------------------------ |
| Database fits comfortably on one machine   | Single-server database                     |
| Need faster reads                          | Read replicas, caching, indexing           |
| Need recovery from server failure          | Replication and failover                   |
| Need more storage than one server provides | Sharding or distributed storage            |
| Need greater write throughput              | Sharding or distributed write architecture |
| Need low-latency access across regions     | Geographic replication or distribution     |
| Need fast analytics on large datasets      | Column-oriented analytical database        |
| Need globally distributed SQL transactions | Distributed SQL database                   |
| Need embedded application storage          | SQLite                                     |
| Need local analytical processing           | DuckDB                                     |

These are starting points, not universal prescriptions.

For example, poor query design or missing indexes can make a database slow long before hardware capacity becomes a problem.

Adding servers to compensate for inefficient queries may simply distribute the inefficiency.

---

## 12. Classroom Experiments

The concepts become more meaningful when students can observe them.

### Experiment 1 — PostgreSQL replication

Create a PostgreSQL primary and standby.

Insert records into the primary and query the standby.

Investigate replication lag, read-only behavior, and what happens when the primary becomes unavailable.

**Question:** Does replication automatically provide failover?

### Experiment 2 — MongoDB sharding

Create a small MongoDB sharded cluster.

Choose a shard key and insert records.

Inspect where documents are stored.

Compare queries that include the shard key with queries that do not.

**Question:** Why does shard-key selection affect query routing?

### Experiment 3 — ClickHouse distributed aggregation

Create a ClickHouse deployment with multiple shards.

Load a dataset and execute aggregation queries.

Compare queries executed against individual shards with queries executed through a distributed table.

**Question:** Which operations can be computed locally, and which require coordination?

### Experiment 4 — SQLite versus DuckDB

Load the same dataset into SQLite and DuckDB.

Compare analytical queries such as:

```sql
SELECT
    category,
    COUNT(*) AS purchases,
    SUM(amount) AS revenue
FROM purchases
GROUP BY category;
```

**Question:** Can a single-machine analytical database outperform a distributed system for a modest dataset?

The answer depends on the workload and configuration, but the experiment illustrates that distribution is not synonymous with speed.

---

## 13. Discussion Questions

1. Can a database be replicated without being sharded?
2. Can a database be sharded without being replicated?
3. Is PostgreSQL table partitioning necessarily distributed?
4. Why might adding read replicas fail to improve write throughput?
5. What happens when an application queries a replica that has not received the latest write?
6. Why can choosing a poor shard key create a performance bottleneck?
7. How does vertical partitioning differ from column-oriented storage?
8. Why are distributed joins potentially expensive?
9. Why doesn't replication replace backups?
10. Under what circumstances might SQLite or DuckDB be preferable to a distributed database?

---

## 14. Key Takeaways

| Concept                 | Core idea                                            | Primary benefit                                   |
| ----------------------- | ---------------------------------------------------- | ------------------------------------------------- |
| Vertical scaling        | Make one machine more powerful                       | Simplicity and capacity                           |
| Horizontal scaling      | Add more machines                                    | Aggregate capacity and throughput                 |
| Replication             | Copy data across nodes                               | Availability and redundancy                       |
| Horizontal partitioning | Divide rows                                          | Manageability and potential parallelism           |
| Sharding                | Distribute data partitions across nodes              | Storage and workload scaling                      |
| Vertical partitioning   | Divide columns or data domains                       | Data locality and separation                      |
| Distributed database    | Coordinate data and operations across machines       | Scale, resilience, geographic reach               |
| Consensus               | Coordinate agreement among nodes                     | Consistent decisions during failures              |
| Quorum                  | Require participation from a sufficient set of nodes | Configurable consistency or durability guarantees |

The most important distinction is:

**Replication, partitioning, and distribution are not competing technologies. They are architectural techniques that can be combined.**

A system may replicate every shard, distribute queries across those shards, and use consensus to coordinate metadata or writes.

But each additional layer introduces tradeoffs.

The goal is not to build the most distributed database possible.

**The goal is to build the simplest architecture that satisfies the application's requirements for performance, availability, consistency, and growth.**

---

## 15. Further Reading

The following documentation provides implementation details and useful starting points for laboratory exercises.

| System      | Documentation                                                                                                        | Topics                                  |
| ----------- | -------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| PostgreSQL  | [High Availability, Load Balancing, and Replication](https://www.postgresql.org/docs/current/high-availability.html) | WAL, streaming replication, failover    |
| PostgreSQL  | [Table Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)                                  | Range, list, and hash partitioning      |
| MySQL       | [Replication](https://dev.mysql.com/doc/refman/8.4/en/replication.html)                                              | Source–replica architecture             |
| MongoDB     | [Replication](https://www.mongodb.com/docs/manual/replication/)                                                      | Replica sets, elections, write concerns |
| MongoDB     | [Sharding](https://www.mongodb.com/docs/manual/sharding/)                                                            | Shard keys, routing, balancing          |
| ClickHouse  | [ReplicatedMergeTree](https://clickhouse.com/docs/engines/table-engines/mergetree-family/replication)                | Replicated data parts                   |
| ClickHouse  | [Distributed Table Engine](https://clickhouse.com/docs/engines/table-engines/special/distributed)                    | Distributed queries and sharding        |
| Cassandra   | [Architecture](https://cassandra.apache.org/doc/latest/cassandra/architecture/)                                      | Partitioning, replication, consistency  |
| CockroachDB | [Architecture](https://www.cockroachlabs.com/docs/stable/architecture/overview)                                      | Distributed SQL, consensus, ranges      |

### Final thought

A useful question to carry into every database architecture discussion is:

> **When we add another database server, are we adding another copy of the data, dividing the existing data, or distributing the work?**

The answer determines what kind of scaling we're actually achieving—and which new problems we're introducing.

**End of handout.**