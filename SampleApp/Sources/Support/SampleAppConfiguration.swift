import Foundation
import BGCategorizationProcessor

enum SampleAppConfiguration {
    static let packageURL = "https://github.com/abhip2565/BGCategorizationProcessor.git"
    static let backgroundTaskIdentifier = "com.abhip2565.BGCategorizationProcessor.sample.processing"
    static let classification = ClassificationConfig(
        minimumConfidence: 0.35,
        sentencesPerChunk: 5,
        maxTextLength: 25_000
    )

    static let starterCategories: [CategoryDefinition] = [
        CategoryDefinition(
            id: "finance",
            label: "Finance",
            descriptors: ["invoice", "expense report", "tax filing", "budget review", "accounts payable"]
        ),
        CategoryDefinition(
            id: "support",
            label: "Support",
            descriptors: ["bug report", "customer issue", "outage update", "ticket escalation", "helpdesk"]
        ),
        CategoryDefinition(
            id: "travel",
            label: "Travel",
            descriptors: ["flight booking", "hotel reservation", "itinerary change", "trip approval", "visa application"]
        ),
        CategoryDefinition(
            id: "legal",
            label: "Legal",
            descriptors: ["contract review", "compliance notice", "policy update", "nda request", "litigation"]
        ),
        CategoryDefinition(
            id: "engineering",
            label: "Engineering",
            descriptors: ["code review", "pull request", "deployment pipeline", "architecture design", "technical debt"]
        ),
        CategoryDefinition(
            id: "marketing",
            label: "Marketing",
            descriptors: ["campaign launch", "brand strategy", "content calendar", "social media analytics", "market research"]
        ),
        CategoryDefinition(
            id: "sales",
            label: "Sales",
            descriptors: ["lead qualification", "pipeline forecast", "deal closure", "quota attainment", "prospect outreach"]
        ),
        CategoryDefinition(
            id: "hr",
            label: "Human Resources",
            descriptors: ["employee onboarding", "performance review", "benefits enrollment", "recruitment pipeline", "workforce planning"]
        ),
        CategoryDefinition(
            id: "product",
            label: "Product",
            descriptors: ["feature prioritization", "roadmap planning", "user research", "product requirements", "release notes"]
        ),
        CategoryDefinition(
            id: "design",
            label: "Design",
            descriptors: ["wireframe review", "design system", "user interface mockup", "accessibility audit", "visual identity"]
        ),
        CategoryDefinition(
            id: "security",
            label: "Security",
            descriptors: ["vulnerability assessment", "penetration testing", "access control review", "incident response", "security audit"]
        ),
        CategoryDefinition(
            id: "operations",
            label: "Operations",
            descriptors: ["supply chain management", "inventory optimization", "vendor coordination", "facilities management", "process improvement"]
        ),
        CategoryDefinition(
            id: "data",
            label: "Data & Analytics",
            descriptors: ["data pipeline", "dashboard creation", "metrics reporting", "data warehouse", "predictive modeling"]
        ),
        CategoryDefinition(
            id: "infrastructure",
            label: "Infrastructure",
            descriptors: ["server provisioning", "network configuration", "cloud migration", "capacity planning", "disaster recovery"]
        ),
        CategoryDefinition(
            id: "compliance",
            label: "Compliance",
            descriptors: ["regulatory filing", "audit preparation", "policy enforcement", "risk assessment", "certification renewal"]
        ),
        CategoryDefinition(
            id: "procurement",
            label: "Procurement",
            descriptors: ["purchase order", "vendor evaluation", "contract negotiation", "spend analysis", "supplier onboarding"]
        ),
        CategoryDefinition(
            id: "customer_success",
            label: "Customer Success",
            descriptors: ["account health check", "churn prevention", "renewal management", "customer onboarding", "satisfaction survey"]
        ),
        CategoryDefinition(
            id: "training",
            label: "Training & Development",
            descriptors: ["learning module", "certification program", "skill assessment", "workshop facilitation", "knowledge base"]
        ),
        CategoryDefinition(
            id: "research",
            label: "Research",
            descriptors: ["literature review", "experiment design", "hypothesis testing", "peer review", "publication submission"]
        ),
        CategoryDefinition(
            id: "communications",
            label: "Communications",
            descriptors: ["press release", "internal memo", "stakeholder update", "crisis communication", "newsletter draft"]
        ),
        CategoryDefinition(
            id: "project_management",
            label: "Project Management",
            descriptors: ["sprint planning", "milestone tracking", "resource allocation", "risk mitigation", "status report"]
        ),
        CategoryDefinition(
            id: "quality_assurance",
            label: "Quality Assurance",
            descriptors: ["test plan", "regression testing", "bug triage", "acceptance criteria", "test automation"]
        ),
        CategoryDefinition(
            id: "partnerships",
            label: "Partnerships",
            descriptors: ["partner onboarding", "co-marketing agreement", "integration planning", "revenue sharing", "joint venture"]
        ),
        CategoryDefinition(
            id: "real_estate",
            label: "Real Estate",
            descriptors: ["lease agreement", "office relocation", "space planning", "property valuation", "tenant improvement"]
        ),
        CategoryDefinition(
            id: "healthcare",
            label: "Healthcare",
            descriptors: ["patient intake", "medical records", "insurance claim", "treatment protocol", "clinical trial"]
        ),
        CategoryDefinition(
            id: "logistics",
            label: "Logistics",
            descriptors: ["shipment tracking", "warehouse management", "freight forwarding", "customs clearance", "route optimization"]
        ),
        CategoryDefinition(
            id: "sustainability",
            label: "Sustainability",
            descriptors: ["carbon footprint", "environmental impact", "green procurement", "waste reduction", "renewable energy"]
        ),
        CategoryDefinition(
            id: "investor_relations",
            label: "Investor Relations",
            descriptors: ["earnings call", "shareholder communication", "SEC filing", "analyst briefing", "annual report"]
        ),
        CategoryDefinition(
            id: "customer_feedback",
            label: "Customer Feedback",
            descriptors: ["product review", "feature request", "complaint resolution", "NPS survey", "user interview"]
        ),
        CategoryDefinition(
            id: "risk_management",
            label: "Risk Management",
            descriptors: ["risk register", "business continuity", "insurance coverage", "threat assessment", "mitigation strategy"]
        ),
    ]

    static let sampleTexts: [String] = [
        "Customer reported a login failure after the outage window and needs a status update.",
        "Please review the new hotel reservation and flight change for next week's client trip.",
        "We need approval on the invoice and updated budget numbers before tax close.",
        "Legal requested a quick contract review before procurement signs the NDA."
    ]

    static let backgroundSampleTexts: [String] = [
        "Tax reconciliation is blocked until the invoice batch is approved.",
        "User account recovery ticket still needs escalation and status messaging.",
        "Travel desk needs a new itinerary after the flight cancellation."
    ]

    /// 500 large text samples (~20,000+ chars each) for stress-testing background processing throughput.
    static let stressTestTexts: [String] = {
        // Each category has multiple rich paragraphs that get cycled and combined to reach 20k+ chars.
        let financeParagraphs: [String] = [
            "The quarterly financial review revealed several discrepancies in the accounts receivable ledger that require immediate attention from the accounting department. Multiple invoices dating back to the previous fiscal quarter remain unreconciled, and the variance between projected revenue and actual collections has widened beyond the acceptable threshold. The CFO has requested a full audit trail for all transactions exceeding ten thousand dollars, along with a revised budget forecast that accounts for the delayed payments from three major enterprise clients. Additionally, the tax compliance team flagged potential issues with cross-border transfer pricing documentation that must be resolved before the annual filing deadline. The internal audit committee has scheduled an extraordinary session to review the findings and determine whether external auditors should be brought in to provide an independent assessment of the financial controls currently in place across all business units.",
            "Capital expenditure planning for the upcoming fiscal year has entered its final review phase, with department heads submitting revised proposals that reflect the board's directive to reduce discretionary spending by fifteen percent while maintaining strategic investment in core growth initiatives. The treasury team has modeled several scenarios involving variable interest rate environments and their impact on the company's floating-rate debt portfolio, concluding that a partial hedging strategy using interest rate swaps would provide adequate downside protection without significantly limiting upside flexibility. Meanwhile, the accounts payable automation project has reached its second milestone, with the new optical character recognition pipeline successfully processing eighty-seven percent of vendor invoices without manual intervention, reducing average processing time from four business days to under six hours.",
            "The annual budget reconciliation process uncovered a pattern of recurring misclassifications between operating expenses and capital expenditures, particularly in the technology infrastructure category where cloud service subscriptions were inconsistently coded across regional offices. The finance transformation team has proposed implementing a centralized chart of accounts with mandatory cost center tagging at the point of purchase order creation, which would eliminate downstream reclassification efforts and improve the accuracy of monthly management reporting. The investor relations team is preparing supplementary disclosures for the upcoming earnings call that address the one-time restructuring charges and their expected impact on adjusted EBITDA margins over the next three quarters.",
            "Foreign exchange exposure management has become a priority following the significant currency fluctuations observed in emerging markets where the company maintains substantial operational footprints. The risk management committee has recommended increasing the hedging ratio for anticipated cash flows denominated in volatile currencies from sixty percent to eighty percent, using a combination of forward contracts and zero-cost collar structures. The cost accounting team has also identified opportunities to consolidate intercompany billing into fewer settlement currencies, which would reduce transaction costs and simplify the monthly elimination process during consolidation. Revenue recognition under the new accounting standard continues to require significant judgment in areas involving multi-element arrangements and variable consideration estimates.",
            "The pension fund actuarial valuation completed last month revealed an increase in the defined benefit obligation driven primarily by lower discount rate assumptions and updated mortality tables reflecting improved life expectancy projections. The compensation committee is evaluating alternative retirement benefit structures for new hires that would shift from defined benefit to enhanced defined contribution plans with employer matching contributions indexed to company performance metrics. The payroll tax compliance team has flagged several jurisdictions where recent legislative changes affect the treatment of equity-based compensation and require updates to withholding calculations before the next vesting event.",
        ]

        let supportParagraphs: [String] = [
            "A critical production incident was reported at 03:47 UTC affecting the authentication service cluster in the us-east-1 region. Approximately twelve percent of login attempts began failing with timeout errors after a routine certificate rotation triggered an unexpected cache invalidation cascade. The on-call engineer escalated to the platform team after initial mitigation attempts proved insufficient. Customer-facing impact included degraded checkout flows, failed password resets, and intermittent session drops across the mobile and web applications. The incident postmortem identified a race condition in the certificate reload handler that had been introduced during the previous deployment cycle and had remained dormant until the specific combination of certificate expiry timing and cache TTL alignment exposed the underlying synchronization defect.",
            "The customer success team has observed a twenty-three percent increase in support ticket volume over the past two weeks, concentrated primarily in the enterprise tier where complex integration workflows are experiencing intermittent data synchronization failures. Root cause analysis traced the issue to a schema migration that altered the column ordering in the events table, causing the change data capture pipeline to misalign field mappings for customers using the legacy webhook format. A hotfix has been deployed to the staging environment and is undergoing validation with affected customers before the production rollout scheduled for the next maintenance window. The technical writing team is preparing updated migration guides and has added automated schema compatibility checks to the CI pipeline to prevent similar regressions.",
            "The observability platform upgrade has entered its final testing phase, with the new distributed tracing backend successfully processing over two million spans per minute during load testing without exceeding the latency budget. The migration from the legacy logging infrastructure to the structured event pipeline is sixty percent complete, with the remaining services scheduled for cutover during the next two sprint cycles. Alert fatigue analysis revealed that thirty-eight percent of pages generated over the past quarter were false positives caused by overly sensitive threshold configurations, prompting the reliability engineering team to implement dynamic baselining using seasonal decomposition algorithms that adapt to normal traffic pattern variations.",
            "Database connection pool exhaustion events have been recurring during peak traffic windows, typically between 14:00 and 16:00 UTC when the batch processing subsystem overlaps with real-time API traffic. The infrastructure team has identified that long-running analytical queries from the reporting service are holding connections for an average of forty-seven seconds, starving the transaction processing layer. Short-term mitigation involves implementing separate connection pools with independent size limits and timeout configurations for OLTP and OLAP workloads. The long-term architectural recommendation is to route analytical queries to read replicas with dedicated connection management, which would also reduce replication lag sensitivity for the primary database cluster.",
            "The mobile application crash rate spiked to four point seven percent following the latest release, up from the baseline of zero point eight percent. Crash telemetry indicates the majority of failures occur during the offline synchronization process when the device transitions from airplane mode to an active network connection while background sync operations are in progress. The engineering team has reproduced the issue in the device lab and traced it to a thread safety violation in the local database write-ahead log compaction routine that was exposed by the new concurrent sync architecture. A patched build has been submitted for expedited app store review with a targeted rollout to the most affected device models first.",
        ]

        let travelParagraphs: [String] = [
            "The corporate travel management team has issued updated guidelines for international business trips following changes to visa processing timelines in several key markets. Employees traveling to the Asia-Pacific region must now submit itinerary requests at least thirty days in advance to allow for additional document verification steps. Hotel accommodation policies have been revised to include sustainability-certified properties wherever available, and the preferred airline program has been expanded to cover three additional carriers operating regional routes. Ground transportation reimbursement limits have been adjusted upward for metropolitan areas where ride-sharing costs have increased significantly over the past year. The global mobility team has also introduced a mandatory pre-travel briefing for destinations with elevated health or security advisories, conducted via a self-service digital module that must be completed and acknowledged before travel authorization is granted.",
            "The annual review of corporate travel spend revealed that airfare costs have increased by eighteen percent year over year, driven primarily by reduced capacity on transatlantic routes and the discontinuation of several corporate discount programs by major carriers. The procurement team is negotiating new volume-based agreements with two alliance partners that would provide guaranteed availability on high-demand routes during peak conference seasons in exchange for minimum annual spend commitments. Duty of care obligations have expanded following recent regulatory guidance requiring employers to maintain real-time location awareness for traveling employees and provide immediate assistance capabilities including emergency medical evacuation and security extraction services in high-risk jurisdictions.",
            "The expense reporting system integration with the new travel booking platform has been completed, enabling automatic receipt capture and policy compliance validation at the point of purchase. Travelers can now photograph receipts using the mobile application, which uses optical character recognition to extract merchant details, amounts, and currency information before matching them against the corresponding itinerary segments. Out-of-policy exceptions are flagged in real time with suggested alternatives, and managers receive consolidated approval requests that include policy deviation summaries and cost comparisons. The analytics dashboard now provides department-level visibility into travel spending patterns, average booking lead times, and compliance rates, enabling finance business partners to identify cost optimization opportunities and address systematic policy violations.",
            "International assignment management has become increasingly complex as the company expands into new markets requiring careful coordination of immigration documentation, tax equalization agreements, and local employment law compliance. The relocation services provider has been tasked with developing standardized packages for three tiers of international assignments ranging from short-term rotational programs of three to six months to permanent transfers requiring full household goods shipments and destination services including housing search assistance, school placement for dependent children, and spousal career support programs. Cross-border payroll processing for assignees involves split salary arrangements with shadow payroll calculations in both home and host countries to ensure correct tax withholding and social security contribution compliance.",
            "The meetings and events team is coordinating logistics for the annual global sales conference, which will bring together over eight hundred participants across twelve time zones for a hybrid format combining in-person sessions at the regional headquarters with virtual participation through the company's collaboration platform. Venue selection criteria include proximity to international airport hubs, availability of simultaneous interpretation services for the four official company languages, and compliance with the company's updated sustainability standards which mandate carbon offset purchases for all event-related air travel and require catering providers to source at least forty percent of ingredients from local suppliers within a two-hundred-kilometer radius of the venue location.",
        ]

        let legalParagraphs: [String] = [
            "The legal department has initiated a comprehensive review of all active vendor contracts in response to newly enacted data protection regulations that impose stricter requirements on cross-border data transfers and processing agreements. Each contract must be evaluated for compliance with the updated standard contractual clauses, and any agreements lacking adequate data breach notification provisions must be renegotiated within the next sixty days. The general counsel has also requested that the intellectual property team conduct a patent landscape analysis for the upcoming product launch to mitigate potential infringement risks identified during the preliminary freedom-to-operate assessment. Outside counsel has been engaged to prepare defensive publications for non-core innovations that the company does not intend to patent but wants to ensure remain in the public domain to prevent competitors from obtaining blocking patents.",
            "The regulatory compliance team has completed its gap analysis of the company's data handling practices against the requirements of the recently enacted comprehensive privacy legislation affecting all operations in the European economic area and the United Kingdom. Key findings include the need to implement a centralized consent management platform capable of recording and honoring granular user preferences across all digital touchpoints, the establishment of a formal data protection impact assessment process for any new processing activity involving sensitive personal data categories, and the appointment of dedicated privacy champions within each business unit who will serve as the primary liaison between operational teams and the central privacy office for day-to-day compliance matters.",
            "The mergers and acquisitions legal team is conducting due diligence on a potential target company whose intellectual property portfolio includes thirty-seven registered patents across four jurisdictions, nineteen pending patent applications, and an extensive trade secret program covering proprietary manufacturing processes and customer algorithms. The due diligence review has uncovered several potential encumbrances including a cross-licensing agreement with a competitor that grants broad field-of-use rights, an unresolved inventorship dispute involving a former employee who claims co-inventor status on three key patents, and inconsistent assignment chains in two jurisdictions where the target company's local subsidiaries failed to execute proper technology transfer agreements at the time of subsidiary formation.",
            "Employment law compliance has become a significant focus area as the company transitions to a permanent hybrid work model that allows employees to work from locations different from their contractual place of employment for up to ninety days per calendar year. The labor and employment team has identified potential implications for income tax withholding obligations in jurisdictions where temporary work arrangements may create nexus for corporate tax purposes, workers compensation coverage gaps for employees working from unregistered locations, and collective bargaining agreement provisions that may restrict unilateral changes to working conditions without prior consultation with employee representative bodies in several European countries where the company maintains significant operations.",
            "The litigation management team has prepared a comprehensive risk assessment of the pending class action lawsuit alleging systematic violations of the telephone consumer protection act through the company's automated marketing communication system. Analysis of the call records and consent documentation suggests that approximately fourteen thousand contacts may have been made to numbers on the internal do-not-call list due to a synchronization failure between the marketing automation platform and the compliance database that persisted for a period of eleven weeks before detection. The estimated exposure range accounting for statutory damages, potential trebling, and class counsel fees has been communicated to the audit committee, and the company's directors and officers insurance carrier has been notified under the relevant policy provisions.",
        ]

        let engineeringParagraphs: [String] = [
            "The platform engineering team has completed the initial rollout of the new continuous integration pipeline, migrating twelve microservices from the legacy Jenkins-based build system to the containerized GitHub Actions workflow. Build times have decreased by an average of forty-three percent due to improved layer caching and parallelized test execution across ephemeral runners. The architecture review board has approved the proposed migration from the monolithic API gateway to an envoy-based service mesh that would provide native support for circuit breaking, retry budgets, and distributed rate limiting without requiring application-level changes. The technical debt backlog has been prioritized using a cost-of-delay model that weights each item by its impact on developer productivity and deployment frequency.",
            "Code review throughput has become a bottleneck as the engineering organization scales beyond one hundred active contributors. The developer experience team has introduced automated pre-review checks that validate code style compliance, test coverage thresholds, and dependency license compatibility before a pull request enters the human review queue. Architecture decision records are now required for any change that modifies public API contracts, introduces new infrastructure dependencies, or alters data retention semantics. The observability team has instrumented the deployment pipeline to capture lead time, change failure rate, and mean time to recovery metrics aligned with the DORA framework for measuring software delivery performance.",
            "The database migration from PostgreSQL twelve to sixteen has been staged across three phases to minimize risk to the production workload. Phase one completed successfully with the schema-compatible upgrades and extension version bumps applied to the staging cluster. Phase two involves enabling the new query planner optimizations and parallel index creation features that are expected to reduce the nightly analytics job duration from ninety minutes to under thirty. The backend team has refactored the connection pooling layer to support the new authentication protocol required by the upgraded server, and load testing confirms that connection establishment latency remains within the established service level objective of fifty milliseconds at the ninety-ninth percentile.",
        ]

        let marketingParagraphs: [String] = [
            "The Q3 integrated marketing campaign has entered its execution phase with coordinated launches across paid search, programmatic display, social media, and email channels. The creative team has produced forty-seven unique ad variations optimized for different audience segments identified through the customer data platform's lookalike modeling capabilities. Attribution modeling has been updated to use a data-driven multi-touch approach that replaces the previous last-click model, providing more accurate visibility into the contribution of upper-funnel awareness channels to pipeline generation. The content marketing team has published a twelve-part thought leadership series that has generated over eight thousand organic backlinks and positioned the company as a category leader in three independent analyst reports.",
            "Brand perception tracking indicates a twelve-point improvement in unaided awareness among the target enterprise buyer persona following the rebranding initiative completed last quarter. The social media team has scaled its presence to seven platforms with dedicated content strategies for each, resulting in a combined follower growth rate of eighteen percent month over month. Influencer partnership agreements have been restructured to include performance-based compensation tiers tied to verified engagement metrics rather than flat-fee arrangements. The marketing operations team has completed the integration between the marketing automation platform and the CRM system, enabling closed-loop reporting that connects campaign touchpoints to revenue outcomes at the individual opportunity level.",
            "The product marketing team is preparing the go-to-market strategy for the upcoming platform release, which includes a new pricing tier designed to capture the mid-market segment that has been underserved by the current enterprise-focused packaging. Competitive battlecards have been updated to reflect three recent market entrants whose messaging directly targets the company's installed base with migration incentives. The demand generation team has negotiated sponsorship packages at four major industry conferences scheduled over the next two quarters, including keynote speaking slots and dedicated demo stations that will showcase the new collaborative workflow features targeted at cross-functional buying committees.",
        ]

        let hrParagraphs: [String] = [
            "The annual employee engagement survey results have been compiled and distributed to department heads for action planning. Overall engagement scores improved by four points compared to the previous year, with notable gains in the categories of career development opportunity and manager effectiveness. However, the compensation competitiveness dimension declined by seven points, prompting the total rewards team to commission an external market benchmarking study covering base salary, variable compensation, equity grants, and benefits valuation across peer companies in the technology sector. The talent acquisition team has reduced average time-to-fill for engineering roles from sixty-two days to thirty-eight days through the implementation of structured interview scorecards and same-day debriefing protocols.",
            "The learning and development team has launched a new management training program designed to address the feedback themes identified in the most recent three-sixty review cycle. The program consists of twelve modules delivered over six months covering topics including giving effective feedback, managing remote and hybrid teams, inclusive leadership practices, and navigating difficult conversations about performance and career trajectory. Participation is mandatory for all people managers and completion rates are tracked as part of the management effectiveness scorecard that influences annual performance ratings. The diversity equity and inclusion team has partnered with external facilitators to deliver unconscious bias training tailored to hiring and promotion decision-making contexts.",
            "The workforce planning model has been updated to reflect the company's strategic growth targets for the next three fiscal years, identifying critical capability gaps in machine learning engineering, cloud security architecture, and enterprise sales leadership. The succession planning process for senior leadership positions has been formalized with the identification of at least two ready-now candidates and two development candidates for each role at the vice president level and above. The employee relations team has implemented a new case management system that centralizes documentation of workplace investigations, accommodation requests, and performance improvement plans with automated escalation triggers and compliance reporting dashboards.",
        ]

        let securityParagraphs: [String] = [
            "The quarterly vulnerability assessment has been completed across all production-facing systems, identifying two hundred and seventeen findings of which fourteen are classified as critical severity based on their potential for remote code execution or unauthorized data access. The application security team has prioritized remediation based on a risk scoring model that considers exploit availability, asset criticality, and compensating control effectiveness. The most urgent finding involves a server-side request forgery vulnerability in the document preview service that could allow an authenticated user to access internal metadata endpoints and potentially pivot to the cloud provider's instance credential service. A patch has been developed and is undergoing security regression testing before deployment.",
            "The security operations center has detected an anomalous pattern of API authentication attempts originating from a distributed set of residential proxy IP addresses, consistent with a credential stuffing campaign targeting enterprise customer accounts. Rate limiting and progressive challenge escalation have been activated, and affected customers have been notified through the established security advisory channel. The threat intelligence team has correlated the attack indicators with a known threat actor group that has been observed targeting SaaS platforms in the same vertical over the past six months. The identity and access management team is accelerating the rollout of mandatory multi-factor authentication for all API access patterns that currently rely solely on long-lived bearer tokens.",
            "The annual penetration testing engagement has concluded with the external security firm delivering their findings report covering network infrastructure, web applications, mobile applications, and social engineering attack vectors. The most significant finding involved a chain of three individually low-severity issues that when combined allowed the testers to escalate from an unauthenticated external position to internal network access with domain administrator privileges within four hours. The remediation plan addresses each link in the attack chain independently while also recommending defense-in-depth improvements to the network segmentation architecture that would limit the blast radius of similar composite attacks in the future.",
        ]

        let dataParagraphs: [String] = [
            "The data engineering team has completed the migration of the core analytics pipeline from the legacy batch-processing architecture to a streaming-first design built on Apache Kafka and Apache Flink. The new pipeline processes an average of three point two million events per minute with end-to-end latency under ninety seconds, compared to the previous six-hour batch window. Data quality monitoring has been integrated at every stage of the pipeline using automated expectation checks that validate schema conformance, referential integrity, and statistical distribution properties. The data governance committee has approved a new data classification framework with four sensitivity tiers that determines encryption requirements, access control policies, and retention periods for each dataset in the warehouse.",
            "The business intelligence team has launched a self-service analytics platform that enables non-technical stakeholders to create and share interactive dashboards without requiring SQL knowledge or data engineering support. The platform includes a curated semantic layer that maps business terminology to the underlying data model, ensuring consistent metric definitions across all reports and eliminating the conflicting numbers problem that had eroded trust in data-driven decision making. The machine learning engineering team has operationalized fourteen predictive models into the production inference pipeline, with automated retraining triggered by data drift detection algorithms that monitor input feature distributions against the training baseline.",
            "The data warehouse optimization project has achieved a forty-seven percent reduction in compute costs through the implementation of incremental materialization, partition pruning, and query result caching across the most frequently accessed datasets. The analytics engineering team has adopted a modular transformation framework that separates staging, intermediate, and mart layers with explicit contracts and automated testing at each boundary. Cross-functional data product teams have been established for the three highest-priority domains with dedicated data engineers, analysts, and product managers who own the end-to-end lifecycle from ingestion through consumption and are accountable for data freshness, accuracy, and accessibility service level agreements.",
        ]

        let logisticsParagraphs: [String] = [
            "The supply chain visibility platform has been upgraded to provide real-time tracking across all transportation modes including ocean freight, air cargo, rail, and last-mile delivery. The new system integrates telemetry data from IoT sensors attached to shipping containers that monitor location, temperature, humidity, and shock events throughout the transit lifecycle. The logistics optimization engine has been retrained on eighteen months of historical shipment data and now generates routing recommendations that account for carrier reliability scores, port congestion forecasts, and dynamic fuel surcharge calculations. Average transit time from manufacturing facility to regional distribution center has decreased by three point eight days since the platform deployment.",
            "Warehouse management system enhancements have been deployed across all twelve distribution centers, introducing wave-less picking algorithms that dynamically prioritize order fulfillment based on carrier pickup schedules, customer service level commitments, and inventory location proximity. The returns processing workflow has been redesigned to reduce average disposition time from fourteen days to three days through automated inspection protocols and machine-learning-based condition grading that determines whether returned items should be restocked, refurbished, or liquidated. The freight audit and payment system has flagged over two hundred thousand dollars in carrier billing discrepancies during the past quarter, with the majority attributed to incorrect accessorial charges and weight-based rating errors.",
            "The customs compliance team has implemented an automated trade classification system that assigns harmonized tariff codes to products using natural language processing models trained on historical classification rulings and product description databases. The system achieves ninety-two percent accuracy on first-pass classification, reducing the time required for customs documentation preparation from an average of four hours per shipment to under thirty minutes. Cross-border trade agreements have been renegotiated with three key trading partners to take advantage of preferential duty rates available under recently enacted free trade provisions, resulting in an estimated annual savings of one point four million dollars in import duties across the affected product categories.",
        ]

        let allParagraphSets = [
            financeParagraphs, supportParagraphs, travelParagraphs, legalParagraphs,
            engineeringParagraphs, marketingParagraphs, hrParagraphs, securityParagraphs,
            dataParagraphs, logisticsParagraphs
        ]

        return (0..<500).map { index in
            let paragraphs = allParagraphSets[index % allParagraphSets.count]
            // Cycle through paragraphs repeatedly until we exceed 20,000 characters
            var text = "[\(index + 1)/500] "
            var paragraphIndex = 0
            while text.count < 20_000 {
                text += paragraphs[paragraphIndex % paragraphs.count]
                text += "\n\n"
                paragraphIndex += 1
            }
            return text
        }
    }()

    static func databasePath() throws -> String {
        let root = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("BGCategorizationProcessorSample", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("sample.sqlite3").path
    }
}
