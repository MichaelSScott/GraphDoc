using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Text;
using Microsoft.Data.Tools.Schema.Sql.UnitTesting;
using Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace GraphDocUnitTests
{
    [TestClass()]
    public class GraphDocUnitTest1 : SqlDatabaseTestClass
    {

        public GraphDocUnitTest1()
        {
            InitializeComponent();
        }

        [TestInitialize()]
        public void TestInitialize()
        {
            base.InitializeTest();
        }
        [TestCleanup()]
        public void TestCleanup()
        {
            base.CleanupTest();
        }

        #region Designer support code

        /// <summary> 
        /// Required method for Designer support - do not modify 
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction GraphDoc_udf_cs_JobStepsTest_TestAction;
            System.ComponentModel.ComponentResourceManager resources = new System.ComponentModel.ComponentResourceManager(typeof(GraphDocUnitTest1));
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.InconclusiveCondition inconclusiveCondition1;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction GraphDoc_usp_cs_DrawDependencyGraphTest_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.InconclusiveCondition inconclusiveCondition2;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction GraphDoc_usp_cs_Job_GraphsTest_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.InconclusiveCondition inconclusiveCondition3;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction GraphDoc_udf_cs_DepTableTest_TestAction;
            Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.InconclusiveCondition inconclusiveCondition4;
            this.GraphDoc_udf_cs_JobStepsTestData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.GraphDoc_usp_cs_DrawDependencyGraphTestData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.GraphDoc_usp_cs_Job_GraphsTestData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            this.GraphDoc_udf_cs_DepTableTestData = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestActions();
            GraphDoc_udf_cs_JobStepsTest_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            inconclusiveCondition1 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.InconclusiveCondition();
            GraphDoc_usp_cs_DrawDependencyGraphTest_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            inconclusiveCondition2 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.InconclusiveCondition();
            GraphDoc_usp_cs_Job_GraphsTest_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            inconclusiveCondition3 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.InconclusiveCondition();
            GraphDoc_udf_cs_DepTableTest_TestAction = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.SqlDatabaseTestAction();
            inconclusiveCondition4 = new Microsoft.Data.Tools.Schema.Sql.UnitTesting.Conditions.InconclusiveCondition();
            // 
            // GraphDoc_udf_cs_JobStepsTestData
            // 
            this.GraphDoc_udf_cs_JobStepsTestData.PosttestAction = null;
            this.GraphDoc_udf_cs_JobStepsTestData.PretestAction = null;
            this.GraphDoc_udf_cs_JobStepsTestData.TestAction = GraphDoc_udf_cs_JobStepsTest_TestAction;
            // 
            // GraphDoc_udf_cs_JobStepsTest_TestAction
            // 
            GraphDoc_udf_cs_JobStepsTest_TestAction.Conditions.Add(inconclusiveCondition1);
            resources.ApplyResources(GraphDoc_udf_cs_JobStepsTest_TestAction, "GraphDoc_udf_cs_JobStepsTest_TestAction");
            // 
            // inconclusiveCondition1
            // 
            inconclusiveCondition1.Enabled = true;
            inconclusiveCondition1.Name = "inconclusiveCondition1";
            // 
            // GraphDoc_usp_cs_DrawDependencyGraphTestData
            // 
            this.GraphDoc_usp_cs_DrawDependencyGraphTestData.PosttestAction = null;
            this.GraphDoc_usp_cs_DrawDependencyGraphTestData.PretestAction = null;
            this.GraphDoc_usp_cs_DrawDependencyGraphTestData.TestAction = GraphDoc_usp_cs_DrawDependencyGraphTest_TestAction;
            // 
            // GraphDoc_usp_cs_DrawDependencyGraphTest_TestAction
            // 
            GraphDoc_usp_cs_DrawDependencyGraphTest_TestAction.Conditions.Add(inconclusiveCondition2);
            resources.ApplyResources(GraphDoc_usp_cs_DrawDependencyGraphTest_TestAction, "GraphDoc_usp_cs_DrawDependencyGraphTest_TestAction");
            // 
            // inconclusiveCondition2
            // 
            inconclusiveCondition2.Enabled = true;
            inconclusiveCondition2.Name = "inconclusiveCondition2";
            // 
            // GraphDoc_usp_cs_Job_GraphsTestData
            // 
            this.GraphDoc_usp_cs_Job_GraphsTestData.PosttestAction = null;
            this.GraphDoc_usp_cs_Job_GraphsTestData.PretestAction = null;
            this.GraphDoc_usp_cs_Job_GraphsTestData.TestAction = GraphDoc_usp_cs_Job_GraphsTest_TestAction;
            // 
            // GraphDoc_usp_cs_Job_GraphsTest_TestAction
            // 
            GraphDoc_usp_cs_Job_GraphsTest_TestAction.Conditions.Add(inconclusiveCondition3);
            resources.ApplyResources(GraphDoc_usp_cs_Job_GraphsTest_TestAction, "GraphDoc_usp_cs_Job_GraphsTest_TestAction");
            // 
            // inconclusiveCondition3
            // 
            inconclusiveCondition3.Enabled = true;
            inconclusiveCondition3.Name = "inconclusiveCondition3";
            // 
            // GraphDoc_udf_cs_DepTableTestData
            // 
            this.GraphDoc_udf_cs_DepTableTestData.PosttestAction = null;
            this.GraphDoc_udf_cs_DepTableTestData.PretestAction = null;
            this.GraphDoc_udf_cs_DepTableTestData.TestAction = GraphDoc_udf_cs_DepTableTest_TestAction;
            // 
            // GraphDoc_udf_cs_DepTableTest_TestAction
            // 
            GraphDoc_udf_cs_DepTableTest_TestAction.Conditions.Add(inconclusiveCondition4);
            resources.ApplyResources(GraphDoc_udf_cs_DepTableTest_TestAction, "GraphDoc_udf_cs_DepTableTest_TestAction");
            // 
            // inconclusiveCondition4
            // 
            inconclusiveCondition4.Enabled = true;
            inconclusiveCondition4.Name = "inconclusiveCondition4";
        }

        #endregion


        #region Additional test attributes
        //
        // You can use the following additional attributes as you write your tests:
        //
        // Use ClassInitialize to run code before running the first test in the class
        // [ClassInitialize()]
        // public static void MyClassInitialize(TestContext testContext) { }
        //
        // Use ClassCleanup to run code after all tests in a class have run
        // [ClassCleanup()]
        // public static void MyClassCleanup() { }
        //
        #endregion

        [TestMethod()]
        public void GraphDoc_udf_cs_JobStepsTest()
        {
            SqlDatabaseTestActions testActions = this.GraphDoc_udf_cs_JobStepsTestData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }

        [TestMethod()]
        public void GraphDoc_usp_cs_DrawDependencyGraphTest()
        {
            SqlDatabaseTestActions testActions = this.GraphDoc_usp_cs_DrawDependencyGraphTestData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }

        [TestMethod()]
        public void GraphDoc_usp_cs_Job_GraphsTest()
        {
            SqlDatabaseTestActions testActions = this.GraphDoc_usp_cs_Job_GraphsTestData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }

        [TestMethod()]
        public void GraphDoc_udf_cs_DepTableTest()
        {
            SqlDatabaseTestActions testActions = this.GraphDoc_udf_cs_DepTableTestData;
            // Execute the pre-test script
            // 
            System.Diagnostics.Trace.WriteLineIf((testActions.PretestAction != null), "Executing pre-test script...");
            SqlExecutionResult[] pretestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PretestAction);
            try
            {
                // Execute the test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.TestAction != null), "Executing test script...");
                SqlExecutionResult[] testResults = TestService.Execute(this.ExecutionContext, this.PrivilegedContext, testActions.TestAction);
            }
            finally
            {
                // Execute the post-test script
                // 
                System.Diagnostics.Trace.WriteLineIf((testActions.PosttestAction != null), "Executing post-test script...");
                SqlExecutionResult[] posttestResults = TestService.Execute(this.PrivilegedContext, this.PrivilegedContext, testActions.PosttestAction);
            }
        }
        private SqlDatabaseTestActions GraphDoc_udf_cs_JobStepsTestData;
        private SqlDatabaseTestActions GraphDoc_usp_cs_DrawDependencyGraphTestData;
        private SqlDatabaseTestActions GraphDoc_usp_cs_Job_GraphsTestData;
        private SqlDatabaseTestActions GraphDoc_udf_cs_DepTableTestData;
    }
}
