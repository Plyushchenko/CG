using System;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshFilter))]
public class MeshGenerator : MonoBehaviour
{
    private MeshFilter _filter;
    private Mesh _mesh;

    /// <summary>
    /// Executed by Unity upon object initialization. <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Awake()
    {
        _filter = GetComponent<MeshFilter>();
        _mesh = _filter.mesh = new Mesh();
        _mesh.MarkDynamic();
    }

    private float F(Vector3 v)
    {
        return (float)(1.3 / v.sqrMagnitude +
        2 / (v - new Vector3(0.8f, 0.6f, 0.8f)).sqrMagnitude +
        0.8 / (v - new Vector3(0.1f, 0.1f, 0.9f)).sqrMagnitude -
         9);
    }
    
    /// <summary>
    /// Executed by Unity on every first frame <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Update()
    {
        List<Vector3> sourceVertices = new List<Vector3>
        {
            new Vector3(0, 0, 0), // 0
            new Vector3(0, 1, 0), // 1
            new Vector3(1, 1, 0), // 2
            new Vector3(1, 0, 0), // 3
            new Vector3(0, 0, 1), // 4
            new Vector3(0, 1, 1), // 5
            new Vector3(1, 1, 1), // 6
            new Vector3(1, 0, 1), // 7
        };

        //a.k.a. indices
        int[] sourceTriangles =
        {
            0, 1, 2, 2, 3, 0, // front
            3, 2, 6, 6, 7, 3, // right
            7, 6, 5, 5, 4, 7, // back
            0, 4, 5, 5, 1, 0, // left
            0, 3, 7, 7, 4, 0, // bottom
            1, 5, 6, 6, 2, 1, // top
        };

        List<List<int>> sourceEdges = new List<List<int>>
        {
            new List<int> {0, 1, 2, 3, 4, 5, 6, 7, 4, 1, 2, 3},
            new List<int> {1, 2, 3, 0, 5, 6, 7, 4, 0, 5, 6, 7},
        };

        List<Vector3> vertices = new List<Vector3>();
        List<int> triangles = new List<int>();
        List<Vector3> normals = new List<Vector3>();

        const float minCoord = -4f;
        const float maxCoord = 4f;
        const float coordStep = 0.1f;

        Vector3 coordStepVector3 = new Vector3(coordStep, coordStep, coordStep);
        List<Vector3> cubeVertices = new List<Vector3>();
        foreach (Vector3 sourceVertex in sourceVertices)
        {
            cubeVertices.Add(Vector3.Scale(sourceVertex, coordStepVector3));
        }

        for (float x = minCoord; x <= maxCoord; x += coordStep)
        {

            for (float y = minCoord; y <= maxCoord; y += coordStep)
            {

                for (float z = minCoord; z <= maxCoord; z += coordStep)
                {
                    int currentVertexMask = 0;
                    List<Vector3> currentVertices = new List<Vector3>(new Vector3[cubeVertices.Count]);
                    List<float> currentVertexValues = new List<float>(new float[cubeVertices.Count]);
                    List<Vector3> currentEdgePositions = new List<Vector3>(new Vector3[sourceEdges[0].Count]); 
                    List<Vector3> currentNormalizedEdgePositions = new List<Vector3>(new Vector3[sourceEdges[0].Count]);
                    for (int i = 0; i < cubeVertices.Count; i++)
                    {
                        currentVertices[i] = cubeVertices[i] + new Vector3(x, y, z);
                        currentVertexValues[i] = F(currentVertices[i]);
                        if (currentVertexValues[i] > 0)
                        {
                            currentVertexMask |= 1 << i;
                        }
                    }


                    Vector3 dxVector3 = new Vector3(0.1f, 0, 0);
                    Vector3 dyVector3 = new Vector3(0, 0.1f, 0);
                    Vector3 dzVector3 = new Vector3(0, 0, 0.1f);
                    for (int i = 0; i < sourceEdges[0].Count; i++)
                    {
                        Vector3 a = currentVertices[sourceEdges[0][i]];
                        Vector3 b = currentVertices[sourceEdges[1][i]];
                        float fa = currentVertexValues[sourceEdges[0][i]];
                        float fb = currentVertexValues[sourceEdges[1][i]];
                        if (fa * fb < 0)
                        {
                            float t = Math.Abs(fa) / (Math.Abs(fa) + Math.Abs(fb));
                            currentEdgePositions[i] = a + t * (b - a);
                            currentNormalizedEdgePositions[i] = new Vector3(
                                F(currentEdgePositions[i] - dxVector3) - F(currentEdgePositions[i] + dxVector3),
                                F(currentEdgePositions[i] - dyVector3) - F(currentEdgePositions[i] + dyVector3),
                                F(currentEdgePositions[i] - dzVector3) - F(currentEdgePositions[i] + dzVector3)
                            ).normalized;
                        }
                    }
                    for (int i = 0; i < MarchingCubes.Tables.CaseToTrianglesCount[currentVertexMask]; i++)
                    {
                        Unity.Mathematics.int3 edgeIds = MarchingCubes.Tables.CaseToVertices[currentVertexMask][i];
                        for (int j = 0; j < 3; j++)
                        {
                            vertices.Add(currentEdgePositions[edgeIds[j]]);
                            normals.Add(currentNormalizedEdgePositions[edgeIds[j]]);
                            triangles.Add(vertices.Count - 1);
                        }
                    }
                }
            }
        }


        // Here unity automatically assumes that vertices are points and hence will be represented as (x, y, z, 1) in homogenous coordinates
        _mesh.Clear();
        _mesh.SetVertices(vertices);
        _mesh.SetTriangles(triangles, 0);
        _mesh.SetNormals(normals);

        // Upload mesh data to the GPU
        _mesh.UploadMeshData(false);
        this.enabled = false;
    }
}
